#!/bin/bash
set -e

# ============================================================
#  학생용 — Lambda 코드만 업데이트
#  인프라(S3, CloudFront, DynamoDB)는 이미 배포되어 있음
#  Lambda 코드 변경 시 ~1분 내 반영
# ============================================================

STACK_NAME="msa-coffee-hands-on"
REGION="ap-northeast-2"

echo ""
echo "========================================="
echo "  🚀 Lambda 배포 중..."
echo "========================================="
echo ""

# AWS 자격증명 확인
echo "[1/3] AWS 자격증명 확인..."
if ! aws sts get-caller-identity --region "$REGION" > /dev/null 2>&1; then
  echo "❌ AWS 자격증명이 설정되지 않았습니다."
  echo "   aws configure 를 실행하세요."
  exit 1
fi
echo "✅ 확인 완료"
echo ""

# SAM 빌드 + 배포 (Lambda만 변경되면 ~1분)
echo "[2/3] sam build..."
sam build

echo "[3/3] sam deploy... (Lambda 코드만 변경 시 ~1분)"
sam deploy \
  --stack-name "$STACK_NAME" \
  --resolve-s3 \
  --capabilities CAPABILITY_IAM \
  --region "$REGION" \
  --no-confirm-changeset

echo ""

# 결과 출력
API_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text --region "$REGION" 2>/dev/null || echo "(확인 불가)")

CF_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontUrl`].OutputValue' \
  --output text --region "$REGION" 2>/dev/null || echo "(확인 불가)")

echo "========================================="
echo "  ✅ 배포 완료!"
echo ""
echo "  🌐 CloudFront: $CF_URL"
echo "  🔗 API:        $API_URL"
echo ""
echo "  테스트: curl $API_URL/api/catalog/categories"
echo "========================================="
