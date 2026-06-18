# ☕ AWS를 통해 MSA 맛보기

> 커피 주문 앱으로 배우는 모놀리식 vs 마이크로서비스 아키텍처
> AWS Lambda + API Gateway로 직접 배포해봅니다

## 빠른 시작

### GitHub Codespace에서 열기

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new)

Codespace가 열리면 Node.js, AWS CLI, SAM CLI가 자동 설치됩니다.

### 실습 흐름

```
Step 1. yarn monolith        → 모놀리식 앱 실행, 정상 동작 확인
Step 2. server.mjs에 버그 삽입  → 전체 앱 다운! (모놀리식의 문제)
Step 3. sam build && sam deploy → Lambda 2개 + API Gateway 배포 (MSA!)
Step 4. Order Lambda만 수정/재배포 → Catalog는 무중단 (독립 배포 & 장애 격리)
Step 5. ./scripts/cleanup.sh   → AWS 리소스 정리
```

자세한 가이드는 [GUIDE.md](./GUIDE.md)를 따라 진행하세요.

## 구조

```
├── monolith/                  # 모놀리식 서버 (모든 API가 한 파일)
│   └── server.mjs
├── lambda/                    # AWS Lambda 핸들러 (MSA로 분리)
│   ├── catalog-service/       # 카탈로그 Lambda
│   └── order-service/         # 주문 Lambda
├── template.yaml              # SAM 템플릿 (Lambda + API Gateway)
├── src/                       # 프론트엔드 (tosslib 디자인 시스템)
└── scripts/                   # 배포/정리/테스트 스크립트
```

## AWS 서비스

| 서비스 | 역할 |
|-------|------|
| **Lambda** | Catalog Service, Order Service 각각 독립 실행 |
| **API Gateway** | `/api/catalog/*` → Catalog Lambda, `/api/orders/*` → Order Lambda |
| **CloudFormation** | SAM으로 인프라 일괄 생성/삭제 |
# msa-session
