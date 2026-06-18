#!/bin/bash
set -e

# ============================================================
#  진행자 전용 — 풀 아키텍처 사전 배포
#  세션 시작 전에 실행 (CloudFront 배포에 5~15분 소요)
# ============================================================

STACK_NAME="msa-coffee-hands-on"
REGION="ap-northeast-2"

echo ""
echo "========================================="
echo "  🏗️  풀 아키텍처 사전 배포"
echo "  S3 + CloudFront + DynamoDB + Lambda + API Gateway"
echo "========================================="
echo ""

# 1. AWS 자격증명 확인
echo "[1/4] AWS 자격증명 확인..."
aws sts get-caller-identity --region "$REGION" > /dev/null
echo "✅ 확인 완료"
echo ""

# 2. SAM 빌드 + 배포
echo "[2/4] SAM 빌드 + 배포 중... (CloudFront 포함, 5~15분 소요)"
sam build
sam deploy \
  --stack-name "$STACK_NAME" \
  --resolve-s3 \
  --capabilities CAPABILITY_IAM \
  --region "$REGION" \
  --no-confirm-changeset
echo "✅ 인프라 배포 완료"
echo ""

# 3. CatalogTable 초기 데이터 투입
echo "[3/5] CatalogTable 데이터 시드..."
bash "$(dirname "$0")/05-seed-catalog.sh"
echo ""

# 4. 프론트엔드 빌드 + S3 업로드
echo "[4/5] 프론트엔드 빌드 + S3 업로드..."

API_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text --region "$REGION")

BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucket`].OutputValue' \
  --output text --region "$REGION")

VITE_API_URL="$API_URL" yarn build 2>/dev/null || npx vite build

aws s3 sync dist/ "s3://$BUCKET/" --delete --region "$REGION"
echo "✅ 프론트엔드 업로드 완료"
echo ""

# 5. 결과 출력
CF_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontUrl`].OutputValue' \
  --output text --region "$REGION")

CATALOG_TABLE=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CatalogTableName`].OutputValue' \
  --output text --region "$REGION")

ORDER_TABLE=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`OrderTableName`].OutputValue' \
  --output text --region "$REGION")

echo "[5/5] 배포 완료!"
echo ""
echo "========================================="
echo "  ✅ 풀 아키텍처 배포 완료!"
echo ""
echo "  🌐 CloudFront:  $CF_URL"
echo "  🔗 API Gateway: $API_URL"
echo "  🪣 S3 Bucket:   $BUCKET"
echo "  📦 CatalogDB:   $CATALOG_TABLE"
echo "  📦 OrderDB:     $ORDER_TABLE"
echo ""
echo "  학생들에게 공유할 URL:"
echo "  $CF_URL"
echo "========================================="
