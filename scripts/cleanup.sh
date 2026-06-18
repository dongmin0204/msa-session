#!/bin/bash
set -e

# ============================================================
#  학생용 정리 스크립트
#  본인 스택만 삭제 (다른 학생 스택에 영향 없음)
# ============================================================

REGION="ap-northeast-2"

IAM_USER=$(aws sts get-caller-identity --query 'Arn' --output text 2>/dev/null | grep -oE 'msa-student-[0-9]+' || echo "")

if [ -z "$IAM_USER" ]; then
  STACK_NAME="msa-coffee-hands-on"
else
  STACK_NAME="msa-coffee-${IAM_USER}"
fi

echo ""
echo "========================================="
echo "  🧹 리소스 정리: ${STACK_NAME}"
echo "========================================="
echo ""

# S3 버킷 비우기
BUCKET=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucket`].OutputValue' \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$BUCKET" ] && [ "$BUCKET" != "None" ]; then
  echo "S3 버킷 비우는 중... ($BUCKET)"
  aws s3 rm "s3://$BUCKET" --recursive --region "$REGION" 2>/dev/null || true
fi

# 스택 삭제
echo "스택 삭제 중..."
aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION" 2>/dev/null || true

echo ""
echo "========================================="
echo "  ✅ ${STACK_NAME} 삭제 완료"
echo "========================================="
