# AWS를 통해 MSA 맛보기

커피 주문 앱으로 모놀리식 구조와 마이크로서비스 구조의 차이를 실습합니다.

모든 API가 하나의 서버에서 동작하는 모놀리식 앱을 실행해보고, 같은 앱을 Catalog Service와 Order Service로 분리한 뒤 AWS Lambda에 배포하여 독립 배포를 직접 체험합니다.

## 실습 목표

1. 모놀리식 구조와 MSA 구조의 차이를 확인합니다.
2. AWS Lambda + API Gateway로 서버리스 MSA를 배포하고, 변경된 서비스만 재배포하는 흐름을 경험합니다.

## 준비하기

### Codespaces에서 열기

[Open in GitHub Codespaces](https://codespaces.new/dongmin0204/msa-session)

Codespace가 열리면 `.devcontainer`의 설정에 따라 Node.js, AWS CLI, SAM CLI, Docker가 자동 설치됩니다. 추가로 `postCreateCommand`가 아래 스크립트를 실행합니다.

```bash
./scripts/01-setup-codespaces.sh
```

스크립트가 끝나면 터미널에 설치된 도구 버전이 출력됩니다. 자동 설치가 실패하면 같은 명령을 다시 실행하세요.

### 로컬에서 실행하기

```bash
yarn install
```

| 도구 | 용도 |
| --- | --- |
| Node.js 20 | 프론트엔드와 로컬 API 서버 실행 |
| Yarn 4 | 의존성 설치. `01-setup-codespaces.sh`에서 Corepack으로 활성화 |
| AWS CLI v2 | AWS 자격증명 설정과 리소스 확인 |
| SAM CLI | Lambda + API Gateway 빌드/배포 |

---

## 프로젝트 구조

```text
.
├── monolith/                  # Step 1: 모놀리식 서버 (모든 API가 한 파일)
│   └── server.mjs
├── microservices/             # Step 2: 로컬 MSA (서비스별 분리)
│   ├── catalog-service.mjs    #   카테고리/상품/옵션 조회
│   ├── order-service.mjs      #   주문 생성/조회
│   └── gateway.mjs            #   API Gateway 역할 (라우팅)
├── lambda/                    # Step 3-6: AWS Lambda 배포용
│   ├── catalog-service/       #   Catalog Lambda 핸들러
│   │   └── index.mjs
│   └── order-service/         #   Order Lambda 핸들러 (DynamoDB 연동)
│       └── index.mjs
├── src/                       # React 프론트엔드 (tosslib 디자인 시스템)
├── public/images/             # 상품 이미지
├── scripts/
│   ├── 01-setup-codespaces.sh  # Codespace 환경 설치
│   ├── 04-deploy.sh           # AWS 배포 (학생별 스택 자동 분리)
│   ├── 05-seed-catalog.sh     # DynamoDB 초기 데이터 투입
│   ├── 08-test-api.sh         # API 테스트
│   └── 09-cleanup.sh          # AWS 리소스 정리
├── template.yaml              # SAM 템플릿 (Lambda, API Gateway, DynamoDB, S3, CloudFront)
├── samconfig.toml             # SAM 배포 설정
└── GUIDE.md                   # 진행자용 상세 가이드
```

---

## 전체 실습 순서

```text
Part 1 — 로컬에서 모놀리식 vs MSA 체험
  Step 1. 모놀리식 앱 실행
  Step 2. 로컬 MSA 앱 실행

Part 2 — AWS에 MSA 배포
  Step 3. AWS 로그인
  Step 4. Lambda 배포
  Step 5. 배포 확인 + 시드 데이터
  Step 6. Lambda 코드 수정 후 재배포 (독립 배포)
  Step 7. 리소스 정리
```

---

## Part 1 — 로컬에서 모놀리식 vs MSA 체험

### Step 1. 모놀리식 앱 실행

모놀리식 모드에서는 프론트엔드와 모든 API가 하나의 개발 서버에서 동작합니다.

```bash
yarn monolith
```

브라우저에서 열어봅니다.

```text
http://localhost:5173
```

확인할 내용:

- 커피, 음료, 디저트 탭이 보입니다.
- 아메리카노를 선택해 옵션(HOT/ICE, 진하기 등)을 고를 수 있습니다.
- 장바구니에 담고 주문할 수 있습니다.

API만 확인하려면 다른 터미널에서 실행합니다.

```bash
./scripts/08-test-api.sh http://localhost:5173
```

> 이 단계에서 백엔드는 `monolith/server.mjs` **한 파일**입니다.
> 메뉴 조회, 옵션 조회, 주문 생성이 모두 같은 프로세스 안에서 실행됩니다.

---

### Step 2. 로컬 MSA 앱 실행

MSA 모드에서는 Catalog, Order, Gateway, Frontend가 각각 따로 실행됩니다.

```bash
yarn msa
```

| 구성요소 | 주소 | 역할 |
| --- | --- | --- |
| Catalog Service | `localhost:3001` | 카테고리, 상품, 옵션 조회 |
| Order Service | `localhost:3002` | 주문 생성/조회 |
| API Gateway | `localhost:4000` | 경로 기반 라우팅 |
| Frontend | `localhost:5173` | 사용자 화면 |

브라우저에서 `http://localhost:5173`을 열어봅니다. Step 1과 **동일한 화면**이 보입니다.

```bash
./scripts/08-test-api.sh http://localhost:4000
```

> 사용자 입장에서는 차이가 없습니다.
> 하지만 내부에서는 Catalog와 Order가 분리되어 있고, Gateway가 요청 경로에 따라 알맞은 서비스로 전달합니다.

---

## Part 2 — AWS에 MSA 배포

### Step 3. AWS 로그인

진행자가 배포한 Access Key로 AWS CLI를 설정합니다.

```bash
aws configure
```

| 항목 | 입력값 |
| --- | --- |
| AWS Access Key ID | 진행자가 배포한 키 |
| AWS Secret Access Key | 진행자가 배포한 시크릿 |
| Default region name | `ap-northeast-2` |
| Default output format | `json` |

> **주의**: Codespaces에서는 `aws login`이나 `aws configure sso`가 동작하지 않습니다 (localhost 콜백 불가).
> 반드시 `aws configure`로 Access Key를 직접 입력하세요.

로그인을 확인합니다.

```bash
aws sts get-caller-identity
```

아래처럼 본인의 IAM 사용자 정보가 출력되면 성공입니다.

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "975050036618",
    "Arn": "arn:aws:iam::975050036618:user/msa-student-XX"
}
```

---

### Step 4. Lambda 배포

배포 스크립트를 실행합니다. 스크립트가 IAM 사용자 이름(예: `msa-student-07`)을 자동 감지하여 **본인 전용 스택**(`msa-coffee-student-07`)을 생성합니다. 다른 학생과 충돌하지 않습니다.

```bash
./scripts/04-deploy.sh
```

> `.aws-sam/build` 권한 에러가 나면 `sudo rm -rf .aws-sam` 후 다시 실행하세요.

배포되는 AWS 리소스:

| 리소스 | 설명 |
| --- | --- |
| **Catalog Lambda** | 카테고리/상품/옵션 조회 (DynamoDB 읽기) |
| **Order Lambda** | 주문 생성/조회 (DynamoDB 읽기/쓰기) |
| **API Gateway** | `/api/catalog/*` → Catalog, `/api/orders/*` → Order |
| **CatalogTable** (DynamoDB) | 상품 데이터 저장 |
| **OrderTable** (DynamoDB) | 주문 데이터 저장 |
| **S3 Bucket** | 프론트엔드 정적 파일 |
| **CloudFront** | CDN + HTTPS + 프론트/API 통합 |

초기 배포는 CloudFront 포함 **10~20분** 소요됩니다. Lambda 코드만 변경한 재배포는 **~1분**입니다.

배포가 완료되면 출력에서 API URL을 확인합니다.

```text
  🔗 API: https://xxxxxxxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod
```

---

### Step 5. 배포 확인 + 시드 데이터

API URL을 환경 변수로 저장합니다.

```bash
export API_URL="https://xxxxxxxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod"
```

카탈로그 데이터를 DynamoDB에 투입합니다. (CatalogTable이 비어있으면 상품이 안 보입니다)

```bash
./scripts/05-seed-catalog.sh msa-coffee-student-XX
```

> `msa-coffee-student-XX` 부분을 본인의 스택 이름으로 바꾸세요. 04-deploy.sh 출력에 표시됩니다.

시드 완료 후 API를 테스트합니다.

```bash
./scripts/08-test-api.sh "$API_URL"
```

또는 개별 확인:

```bash
# Catalog Lambda
curl "$API_URL/api/catalog/categories"
curl "$API_URL/api/catalog/items"

# Order Lambda
curl -X POST "$API_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

확인할 내용:

- `/api/catalog/*` → **Catalog Lambda**가 응답합니다.
- `/api/orders/*` → **Order Lambda**가 응답합니다.
- 하나의 API Gateway URL 뒤에서 **서로 다른 Lambda**가 동작합니다.

---

### Step 6. Lambda 코드 수정 후 재배포 (독립 배포)

`lambda/order-service/index.mjs`를 열고 주문 성공 응답을 수정합니다.

기존 코드:

```javascript
return { statusCode: 200, headers, body: JSON.stringify({ orderId }) };
```

수정 코드:

```javascript
return { statusCode: 200, headers, body: JSON.stringify({ orderId, message: '주문 감사합니다!' }) };
```

재배포합니다.

```bash
./scripts/04-deploy.sh
```

> Lambda 코드만 변경했으므로 **~1분**이면 반영됩니다.

주문 API를 다시 호출합니다.

```bash
curl -X POST "$API_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

확인할 내용:

- 주문 응답에 `"message": "주문 감사합니다!"`가 추가됩니다.
- `curl "$API_URL/api/catalog/items"` — Catalog은 **전혀 변하지 않았습니다**. Catalog Lambda는 건드리지 않았으니까요.
- **변경된 서비스만 재배포해도 전체 시스템이 계속 동작합니다.**

---

### Step 7. 리소스 정리

실습이 끝나면 본인 스택의 AWS 리소스를 정리합니다.

```bash
./scripts/09-cleanup.sh
```

스크립트가 본인 IAM 사용자 이름을 감지하여 **본인 스택만** 삭제합니다.

삭제 대상:

- Lambda 함수 2개 (Catalog, Order)
- API Gateway
- DynamoDB 테이블 2개 (CatalogTable, OrderTable)
- S3 버킷 (프론트엔드)
- CloudFront 배포
- IAM Role
- CloudFormation 스택 전체

---

## 자주 쓰는 명령어

| 명령어 | 설명 |
| --- | --- |
| `yarn monolith` | 모놀리식 모드 실행 |
| `yarn msa` | 로컬 MSA 모드 실행 |
| `aws configure` | AWS 자격증명 설정 |
| `aws sts get-caller-identity` | 로그인 확인 |
| `./scripts/04-deploy.sh` | AWS 배포 (빌드 + 배포, 학생별 스택 자동 분리) |
| `./scripts/05-seed-catalog.sh 스택이름` | DynamoDB에 카탈로그 데이터 투입 |
| `./scripts/08-test-api.sh URL` | API 테스트 |
| `./scripts/09-cleanup.sh` | 본인 AWS 리소스 정리 |
| `yarn build` | 프론트엔드 프로덕션 빌드 |

## 트러블슈팅

| 증상 | 해결 |
| --- | --- |
| `sam build` 권한 에러 (`not writable`) | `sudo rm -rf .aws-sam` 후 재실행 |
| `aws login` 에서 `127.0.0.1 연결 거부` | Codespaces에서는 `aws configure`만 사용 |
| `sam deploy` 에서 `ROLLBACK_COMPLETE` | `aws cloudformation delete-stack --stack-name 스택이름 --region ap-northeast-2` 후 재배포 |
| 카탈로그 API 응답이 빈 배열 | `./scripts/05-seed-catalog.sh 스택이름` 실행 |
| CloudFront URL에서 `Access Denied` | `yarn build && aws s3 sync dist/ s3://버킷이름/ --delete --region ap-northeast-2` |

## 배포되는 AWS 아키텍처

```text
사용자 (브라우저)
  │ HTTPS
  ▼
CloudFront (CDN)
  ├── 정적 파일 (HTML/JS/CSS) ← S3 Bucket
  └── /api/* ← API Gateway
                 ├── /api/catalog/* → Catalog Lambda → CatalogTable (DynamoDB)
                 └── /api/orders/*  → Order Lambda   → OrderTable (DynamoDB)
```

| AWS 서비스 | 역할 |
| --- | --- |
| **Lambda** | Catalog Service / Order Service 각각 독립 실행 |
| **API Gateway** | URL 경로 기반으로 요청을 올바른 Lambda로 라우팅 |
| **DynamoDB** | CatalogTable (상품 데이터), OrderTable (주문 데이터) |
| **S3** | 프론트엔드 정적 파일 호스팅 |
| **CloudFront** | CDN + HTTPS + 프론트엔드와 API를 하나의 도메인으로 통합 |
| **CloudFormation** | `sam deploy`로 위 리소스를 한 번에 생성/수정/삭제 |

더 자세한 진행자용 설명은 [GUIDE.md](./GUIDE.md)를 참고하세요.
