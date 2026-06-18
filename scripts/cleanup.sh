#!/bin/bash
set -e

# ============================================================
#  AWS 리소스 전체 정리
#  S3 버킷 비우기 → CloudFormation 스택 삭제
# ============================================================

STACK_NAME="msa-coffee-hands-on"
REGION="ap-northeast-2"

echo ""
echo "========================================="
echo "  🧹 AWS 리소스 정리 시작"
echo "========================================="
echo ""

# 1. S3 버킷 비우기 (비어있어야 삭제 가능)
echo "[1/4] S3 버킷 비우기..."
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucket`].OutputValue' \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$BUCKET" ] && [ "$BUCKET" != "None" ]; then
  aws s3 rm "s3://$BUCKET" --recursive --region "$REGION" 2>/dev/null || true
  echo "  → $BUCKET 비우기 완료"
else
  echo "  → S3 버킷 없음 (이미 삭제됨)"
fi
echo ""

# 2. CloudFormation 스택 삭제
echo "[2/4] CloudFormation 스택 삭제 중..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
echo "  → 삭제 요청 완료 (1~3분 소요)"

# 3. 삭제 대기
echo "[3/4] 스택 삭제 완료 대기 중..."
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null || true
echo "  → 스택 삭제 완료!"
echo ""

# 4. SAM 배포 S3 버킷 정리
echo "[4/4] SAM 배포 S3 버킷 정리..."
SAM_BUCKET=$(aws s3 ls --region "$REGION" | grep "aws-sam-cli-managed" | awk '{print $3}')
if [ -n "$SAM_BUCKET" ]; then
  aws s3 rm "s3://$SAM_BUCKET" --recursive --region "$REGION" 2>/dev/null || true
  aws s3 rb "s3://$SAM_BUCKET" --region "$REGION" 2>/dev/null || true
  echo "  → SAM 버킷 정리 완료"
else
  echo "  → SAM 버킷 없음"
fi

echo ""
echo "========================================="
echo "  ✅ 모든 AWS 리소스 정리 완료!"
echo "  Lambda, API Gateway, CloudFront,"
echo "  S3, DynamoDB 전부 삭제되었습니다."
echo "========================================="
