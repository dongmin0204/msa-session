# AWS를 통해 MSA 맛보기 — 실습 가이드

> 진행자가 풀 아키텍처(S3 + CloudFront + DynamoDB + Lambda + API Gateway)를
> 사전 배포해둔 상태에서 진행합니다.

## Step 1. 모놀리식 앱 확인하기 (5분)

터미널에서 실행:

```bash
yarn monolith
```

브라우저에서 `http://localhost:5173` 을 열어보세요.

**확인할 것:**
- [ ] 커피, 음료, 디저트 탭이 보인다
- [ ] 아메리카노를 눌러서 옵션을 선택할 수 있다
- [ ] 장바구니에 담고 주문할 수 있다

> 지금 이 앱의 백엔드는 `monolith/server.mjs` **한 파일**입니다.
> 메뉴 조회, 옵션 조회, 주문 — 모든 API가 한 프로세스에서 동작합니다.

---

## Step 2. 모놀리식의 문제 체험하기 (5분)

`monolith/server.mjs` 파일을 열고, 주문 API를 찾으세요:

```javascript
app.post('/api/orders', async (c) => {
```

이 함수의 **첫 줄에** 아래 코드를 추가하세요:

```javascript
  throw new Error('💥 주문 서비스에 버그 발생!');
```

저장하고, 브라우저를 새로고침하세요.

**무슨 일이 벌어졌나요?**
- [ ] 메뉴 목록도 안 보인다!
- [ ] 주문뿐 아니라 **전체 앱이 죽었다**

> 💡 **이게 모놀리식의 문제입니다.**
> 주문 기능 하나가 고장났는데, 메뉴 조회까지 같이 죽어버렸습니다.

`Ctrl+C`로 서버를 종료하고, 추가한 throw 줄을 **삭제**하세요.

---

## Step 3. AWS에 배포된 MSA 확인하기 (5분)

진행자가 공유한 **CloudFront URL**을 브라우저에서 열어보세요:

```
https://xxxxxxxxxx.cloudfront.net
```

**이 앱은 AWS에서 이렇게 동작하고 있습니다:**

```
브라우저
  ↓ HTTPS
CloudFront (CDN)
  ├── 화면 (HTML/JS/CSS) ← S3
  └── /api/* ← API Gateway
                ├── /api/catalog/* → Catalog Lambda
                └── /api/orders/*  → Order Lambda → DynamoDB
```

**확인할 것:**
- [ ] 로컬에서 본 것과 **똑같은 앱**이 AWS에서 동작한다
- [ ] 메뉴 조회, 주문이 정상 동작한다

---

## Step 4. Lambda 코드 수정 + 재배포 (10분)

### 4-1. AWS 자격증명 설정

```bash
aws configure
```

진행자가 안내하는 Access Key, Secret Key, Region(`ap-northeast-2`)을 입력하세요.

### 4-2. Order Lambda 수정

`lambda/order-service/index.mjs`를 열고, 주문 성공 응답을 수정해보세요:

```javascript
// 이 줄을 찾아서:
return { statusCode: 200, headers, body: JSON.stringify({ orderId }) };

// 이렇게 바꾸세요:
return { statusCode: 200, headers, body: JSON.stringify({ orderId, message: '☕ 주문 감사합니다!' }) };
```

### 4-3. 배포

```bash
sam build && sam deploy
```

> Lambda 코드만 변경했으므로 **~1분**이면 배포 완료됩니다.
> (CloudFront, S3, DynamoDB는 이미 있으므로 건드리지 않습니다)

### 4-4. 확인

```bash
# API Gateway URL로 직접 테스트
curl $API_URL/api/catalog/categories    # ← Catalog Lambda 응답
curl -X POST $API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

**확인할 것:**
- [ ] 주문 응답에 `"☕ 주문 감사합니다!"` 메시지가 추가되었다
- [ ] 카탈로그 조회는 **전혀 변하지 않았다** — Catalog Lambda는 안 건드렸으니까!

> 🎉 **이게 MSA의 독립 배포입니다!**

---

## Step 5. 장애 격리 체험 (5분)

Order Lambda에 의도적 에러를 넣어봅시다.

`lambda/order-service/index.mjs`의 handler 함수 **맨 첫 줄**에:

```javascript
  throw new Error('💥 Order Service 장애 발생!');
```

재배포:

```bash
sam build && sam deploy
```

테스트:

```bash
# Catalog — 정상! ✅
curl $API_URL/api/catalog/categories
curl $API_URL/api/catalog/items

# 주문 — 에러! ❌
curl -X POST $API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'
```

**확인할 것:**
- [ ] 카테고리/상품 조회는 **정상** ✅
- [ ] 주문만 에러 ❌

> 🎉 **이게 MSA의 장애 격리입니다!**
> Step 2에서는 하나가 죽으니 전부 죽었는데,
> MSA에서는 Order가 죽어도 Catalog은 멀쩡합니다.

에러 코드를 **삭제**하고 `sam build && sam deploy`로 복구하세요.

---

## Step 6. 정리 + 다음 단계 (5분)

### 오늘 쓴 AWS 서비스

```
CloudFront ─── 전 세계 CDN, HTTPS 자동
S3 ─────────── 프론트엔드 파일 저장
API Gateway ── URL 하나로 여러 Lambda 라우팅
Lambda ─────── 서버 없이 코드만 올리면 실행
DynamoDB ───── 주문 데이터 저장 (서버리스 DB)
CloudFormation ─ sam deploy로 전부 한 번에 생성/삭제
```

### 모놀리식 vs MSA

| 모놀리식 | MSA (Lambda) |
|---------|-------------|
| 한 파일에 모든 기능 | 기능별로 Lambda 분리 |
| 하나 죽으면 전부 죽음 | 하나 죽어도 나머지 정상 |
| 전체 재배포 필요 | 변경된 Lambda만 재배포 (~1분) |
| 서버 직접 관리 | AWS가 알아서 실행 |

### 더 배우고 싶다면

```
[오늘]                      [다음 단계]                  [그 다음]
Lambda (함수 실행)        →   ECS/Fargate (컨테이너)    →   EKS (Kubernetes)
API Gateway (라우팅)      →   ALB (로드밸런서)           →   Service Mesh
DynamoDB (NoSQL)         →   RDS (관계형 DB)           →   Aurora Serverless
sam deploy (수동 배포)    →   CodePipeline (CI/CD)      →   GitOps
```
