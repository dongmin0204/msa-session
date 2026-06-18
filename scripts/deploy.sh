#!/bin/bash
set -e

# ============================================================
#  학생용 배포 스크립트
#  IAM 사용자 이름에서 자동으로 스택 이름을 생성하여 충돌 방지
#  예: msa-student-07 → 스택 이름 msa-coffee-student-07
# ============================================================

REGION="ap-northeast-2"
S3_BUCKET="msa-coffee-sam-artifacts-975050036618"

# IAM 사용자 이름으로 고유 스택 이름 생성
IAM_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | grep -oE 'msa-student-[0-9]+' || echo "")

if [ -z "$IAM_USER" ]; then
  STACK_NAME="msa-coffee-hands-on"
  S3_PREFIX="default"
else
  STACK_NAME="msa-coffee-${IAM_USER}"
  S3_PREFIX="${IAM_USER}"
fi

echo ""
echo "========================================="
echo "  🚀 배포 시작"
echo "  스택 이름: ${STACK_NAME}"
echo "========================================="
echo ""

echo "[1/3] AWS 자격증명 확인..."
aws sts get-caller-identity --region "$REGION"
echo ""

echo "[2/3] sam build..."
sam build

echo "[3/3] sam deploy... (초기 10~20분, 재배포 ~1분)"
sam deploy \
  --stack-name "$STACK_NAME" \
  --s3-bucket "$S3_BUCKET" \
  --s3-prefix "$S3_PREFIX" \
  --capabilities CAPABILITY_IAM \
  --region "$REGION" \
  --no-confirm-changeset

echo ""

API_URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text --region "$REGION" 2>/dev/null || echo "(확인 불가)")

echo "========================================="
echo "  ✅ 배포 완료!"
echo ""
echo "  🔗 API: $API_URL"
echo ""
echo "  테스트:"
echo "    export API_URL=\"$API_URL\""
echo "    ./scripts/test-api.sh \"\$API_URL\""
echo "========================================="
