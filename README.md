# AWS를 통해 MSA 맛보기

커피 주문 앱으로 모놀리식 구조와 마이크로서비스 구조의 차이를 실습합니다.

처음에는 모든 API가 하나의 Node.js 서버에서 동작하는 모놀리식 앱을 실행하고, 이후 Catalog/Order 서비스를 분리한 MSA 구조와 AWS Lambda 배포 흐름을 확인합니다.

## 실습 목표

- 모놀리식에서는 하나의 기능 장애가 전체 앱에 영향을 줄 수 있음을 확인합니다.
- Catalog Service와 Order Service를 분리하면 독립적으로 실행, 배포, 장애 격리가 가능함을 확인합니다.
- AWS Lambda, API Gateway, CloudFormation/SAM을 사용해 서버리스 MSA 배포 흐름을 경험합니다.

## 준비하기

### Codespaces에서 열기

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/dongmin0204/msa-session)

Codespaces를 사용하면 Node.js, AWS CLI, SAM CLI가 포함된 개발 환경에서 바로 시작할 수 있습니다.

Codespace가 처음 열릴 때 아래 스크립트가 자동 실행되어 Yarn, AWS CLI, SAM CLI, 프로젝트 의존성을 준비합니다.

```bash
./scripts/setup-codespaces.sh
```

자동 설치가 실패했거나 Codespace를 재빌드한 뒤 도구를 다시 확인하고 싶으면 같은 명령을 터미널에서 직접 실행하세요.

### 로컬에서 실행하기

```bash
yarn install
```

필요한 버전은 다음과 같습니다.

| 도구 | 용도 |
| --- | --- |
| Node.js 20 | 프론트엔드와 로컬 API 서버 실행 |
| Yarn 4 | 의존성 설치와 실행 스크립트 관리. `setup-codespaces.sh`에서 Corepack으로 활성화 |
| AWS CLI | AWS 로그인과 배포 권한 확인. `setup-codespaces.sh`에서 누락 시 설치 |
| SAM CLI | Lambda/API Gateway 배포 |

## 프로젝트 구조

```text
.
├── monolith/                  # 모놀리식 서버: 모든 API가 한 파일에 있음
│   └── server.mjs
├── microservices/             # 로컬 MSA 실습용 서비스
│   ├── catalog-service.mjs
│   ├── order-service.mjs
│   └── gateway.mjs
├── lambda/                    # AWS Lambda 배포용 서비스
│   ├── catalog-service/
│   └── order-service/
├── src/                       # React 프론트엔드
├── public/                    # 상품 이미지 등 정적 파일
├── scripts/                   # 실행, 배포, 테스트 스크립트
├── template.yaml              # AWS SAM 템플릿
└── GUIDE.md                   # 진행자용 상세 가이드
```

## 전체 실습 순서

```text
Step 1. 모놀리식 앱 실행
Step 2. 모놀리식 장애 체험
Step 3. 로컬 MSA 앱 실행
Step 4. MSA 장애 격리 확인
Step 5. Codespaces에서 AWS 로그인
Step 6. AWS Lambda 배포
Step 7. Lambda 코드 수정 후 재배포
Step 8. AWS에서 장애 격리 확인
Step 9. 리소스 정리
```

## Step 1. 모놀리식 앱 실행

모놀리식 모드에서는 프론트엔드와 모든 API가 하나의 개발 서버에서 동작합니다.

```bash
yarn monolith
```

브라우저에서 아래 주소를 엽니다.

```text
http://localhost:5173
```

확인할 내용:

- 커피, 음료, 디저트 탭이 보입니다.
- 아메리카노를 선택해 옵션을 고를 수 있습니다.
- 장바구니에 담고 주문할 수 있습니다.

API만 빠르게 확인하려면 다른 터미널에서 실행합니다.

```bash
./scripts/test-api.sh http://localhost:5173
```

이 단계에서 백엔드는 [monolith/server.mjs](./monolith/server.mjs) 한 파일입니다. 메뉴 조회, 상품 상세 조회, 주문 생성 API가 모두 같은 프로세스 안에서 실행됩니다.

## Step 2. 모놀리식 장애 체험

[monolith/server.mjs](./monolith/server.mjs)에서 주문 API를 찾습니다.

```javascript
app.post('/api/orders', async (c) => {
```

함수의 첫 줄에 아래 코드를 추가합니다.

```javascript
  throw new Error('주문 서비스에 버그 발생!');
```

파일을 저장한 뒤 브라우저를 새로고침하고 주문을 시도합니다.

확인할 내용:

- 주문 기능이 실패합니다.
- 같은 서버에서 실행 중인 다른 API도 영향을 받을 수 있습니다.
- 하나의 프로세스에 여러 기능이 묶여 있으면 장애 범위가 커질 수 있습니다.

확인이 끝나면 추가한 `throw new Error(...)` 줄을 삭제하고 서버를 재시작합니다.

```bash
Ctrl+C
yarn monolith
```

## Step 3. 로컬 MSA 앱 실행

MSA 모드에서는 Catalog Service, Order Service, Gateway, Frontend가 각각 따로 실행됩니다.

```bash
yarn msa
```

실행되는 구성은 다음과 같습니다.

| 구성요소 | 주소 | 역할 |
| --- | --- | --- |
| Catalog Service | `http://localhost:3001` | 카테고리, 상품 조회 |
| Order Service | `http://localhost:3002` | 주문 생성 |
| API Gateway | `http://localhost:4000` | `/api/catalog/*`, `/api/orders/*` 라우팅 |
| Frontend | `http://localhost:5173` | 사용자 화면 |

브라우저에서는 이전과 동일하게 접속합니다.

```text
http://localhost:5173
```

Gateway를 기준으로 API를 테스트합니다.

```bash
./scripts/test-api.sh http://localhost:4000
```

확인할 내용:

- 사용자는 같은 화면을 봅니다.
- 내부 구조는 Catalog와 Order가 분리되어 있습니다.
- Gateway가 요청 경로에 따라 알맞은 서비스로 전달합니다.

## Step 4. MSA 장애 격리 확인

[microservices/order-service.mjs](./microservices/order-service.mjs)에서 주문 API 처리 부분에 의도적으로 에러를 넣습니다.

```javascript
throw new Error('Order Service 장애 발생!');
```

저장 후 MSA 서버가 자동으로 반영되지 않으면 `Ctrl+C`로 종료하고 다시 실행합니다.

```bash
yarn msa
```

Catalog API를 확인합니다.

```bash
curl http://localhost:4000/api/catalog/categories
curl http://localhost:4000/api/catalog/items
```

Order API를 확인합니다.

```bash
curl -X POST http://localhost:4000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

확인할 내용:

- Catalog API는 정상 응답합니다.
- Order API만 실패합니다.
- 서비스가 분리되어 있으면 장애가 전체 기능으로 번지지 않습니다.

확인이 끝나면 추가한 에러 코드를 삭제하고 다시 실행합니다.

## Step 5. Codespaces에서 AWS 로그인

AWS 배포 실습은 Codespaces 터미널에서 각자 본인의 AWS 계정으로 로그인한 뒤 진행합니다. 브라우저에서 AWS 로그인을 완료하고, Codespaces의 AWS CLI가 그 로그인 정보를 사용하게 만드는 흐름입니다.

먼저 Codespaces 터미널에서 AWS CLI가 설치되어 있는지 확인합니다.

```bash
aws --version
sam --version
```

AWS SSO 또는 IAM Identity Center를 사용하는 계정이면 아래 명령으로 로그인 설정을 시작합니다.

```bash
aws configure sso
```

터미널에 표시되는 안내에 따라 진행합니다.

| 항목 | 입력값 |
| --- | --- |
| SSO session name | 원하는 이름. 예: `msa-session` |
| SSO start URL | 본인 AWS 로그인 포털 URL |
| SSO region | 관리자가 안내한 SSO Region |
| CLI default client Region | `ap-northeast-2` |
| CLI default output format | `json` |
| CLI profile name | 원하는 이름. 예: `msa-session` |

명령 실행 중 브라우저 인증 페이지가 열리면 본인 AWS 계정으로 로그인하고 권한 요청을 승인합니다.
브라우저가 자동으로 열리지 않으면 터미널에 표시된 URL을 복사해 브라우저에서 열고, 함께 표시된 인증 코드를 입력합니다.

프로필 이름을 `msa-session`으로 만들었다면, 현재 터미널에서 이 프로필을 사용하도록 설정합니다.

```bash
export AWS_PROFILE=msa-session
export AWS_DEFAULT_REGION=ap-northeast-2
```

이미 SSO 설정을 마친 Codespace에서 다시 로그인해야 할 때는 아래 명령을 사용합니다.

```bash
aws sso login --profile msa-session
```

로그인이 잘 되었는지 확인합니다.

```bash
aws sts get-caller-identity
```

계정 ID와 사용자/역할 ARN이 출력되면 배포 준비가 끝난 것입니다.

배포 전에 SAM 템플릿을 빌드합니다.

```bash
sam build
```

## Step 6. AWS Lambda 배포

아래 명령으로 Lambda와 API Gateway를 배포합니다.

```bash
sam deploy
```

배포가 끝나면 출력에서 API Gateway URL을 확인합니다. 예시는 다음과 같습니다.

```text
https://xxxxxxxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod
```

API Gateway URL을 환경 변수로 저장하면 테스트하기 편합니다.

```bash
export API_URL="https://xxxxxxxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod"
```

배포된 API를 테스트합니다.

```bash
./scripts/test-api.sh "$API_URL"
```

확인할 내용:

- `/api/catalog/categories`가 Catalog Lambda로 연결됩니다.
- `/api/catalog/items`가 Catalog Lambda로 연결됩니다.
- `/api/orders`가 Order Lambda로 연결됩니다.

## Step 7. Lambda 코드 수정 후 재배포

[lambda/order-service/index.mjs](./lambda/order-service/index.mjs)를 열고 주문 성공 응답을 수정합니다.

기존 코드:

```javascript
return { statusCode: 200, headers, body: JSON.stringify({ orderId }) };
```

수정 코드:

```javascript
return { statusCode: 200, headers, body: JSON.stringify({ orderId, message: '주문 감사합니다!' }) };
```

다시 빌드하고 배포합니다.

```bash
sam build
sam deploy
```

주문 API를 다시 호출합니다.

```bash
curl -X POST "$API_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

확인할 내용:

- 주문 응답에 `message`가 추가됩니다.
- Catalog Lambda는 수정하지 않았으므로 카탈로그 응답은 그대로입니다.
- 변경된 서비스만 다시 배포해도 전체 시스템이 계속 동작합니다.

## Step 8. AWS에서 장애 격리 확인

[lambda/order-service/index.mjs](./lambda/order-service/index.mjs)의 handler 시작 부분에 의도적 에러를 넣습니다.

```javascript
throw new Error('Order Service 장애 발생!');
```

다시 배포합니다.

```bash
sam build
sam deploy
```

Catalog API와 Order API를 각각 확인합니다.

```bash
curl "$API_URL/api/catalog/categories"
curl "$API_URL/api/catalog/items"
curl -X POST "$API_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

확인할 내용:

- Catalog API는 정상입니다.
- Order API만 실패합니다.
- Lambda 단위로 분리된 서비스는 장애 격리가 가능합니다.

확인이 끝나면 에러 코드를 삭제하고 복구 배포를 합니다.

```bash
sam build
sam deploy
```

## Step 9. 정리하기

실습이 끝나면 AWS 리소스를 정리합니다.

```bash
./scripts/cleanup.sh
```

삭제 대상:

- Lambda 함수
- API Gateway
- CloudFormation Stack
- 실습에서 생성한 관련 리소스

정리 후에는 AWS 콘솔에서 CloudFormation Stack이 삭제되었는지 확인합니다.

## 자주 쓰는 명령어

| 명령어 | 설명 |
| --- | --- |
| `yarn monolith` | 모놀리식 모드 실행 |
| `yarn msa` | 로컬 MSA 모드 실행 |
| `yarn build` | 프론트엔드 프로덕션 빌드 |
| `./scripts/test-api.sh http://localhost:5173` | 모놀리식 API 테스트 |
| `./scripts/test-api.sh http://localhost:4000` | 로컬 MSA Gateway API 테스트 |
| `sam build` | Lambda 배포 패키지 빌드 |
| `sam deploy` | AWS 배포 |
| `./scripts/cleanup.sh` | AWS 리소스 정리 |

## 실습에서 사용하는 AWS 서비스

| 서비스 | 역할 |
| --- | --- |
| Lambda | Catalog Service와 Order Service 실행 |
| API Gateway | `/api/catalog/*`, `/api/orders/*` 라우팅 |
| CloudFormation | SAM 템플릿 기반 인프라 생성/수정/삭제 |
| S3 | 프론트엔드 정적 파일 저장에 활용 가능 |
| CloudFront | 정적 파일과 API를 하나의 HTTPS 엔드포인트로 제공할 때 활용 가능 |
| DynamoDB | 주문 데이터 저장소로 확장 가능 |

더 자세한 진행자용 설명은 [GUIDE.md](./GUIDE.md)를 참고하세요.
