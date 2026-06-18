#!/bin/bash
set -euo pipefail

# ============================================================
#  진행자 전용 — 세션 후 학생용 IAM 사용자 전부 삭제
# ============================================================

POLICY_NAME="msa-session-student-policy"
GROUP_NAME="msa-session-students"

echo ""
echo "========================================="
echo "  🧹 학생용 IAM 자격증명 전부 삭제"
echo "========================================="
echo ""

# 그룹 멤버 조회 + 삭제
MEMBERS=$(aws iam get-group --group-name "$GROUP_NAME" --query 'Users[].UserName' --output text 2>/dev/null || echo "")

for USERNAME in $MEMBERS; do
  echo "  삭제 중: $USERNAME"

  # Access Key 삭제
  KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")
  for key in $KEYS; do
    aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$key" 2>/dev/null || true
  done

  # 그룹에서 제거
  aws iam remove-user-from-group --user-name "$USERNAME" --group-name "$GROUP_NAME" 2>/dev/null || true

  # 사용자 삭제
  aws iam delete-user --user-name "$USERNAME" 2>/dev/null || true
  echo "    → 삭제 완료"
done

# 그룹 정책 해제 + 그룹 삭제
POLICY_ARN=$(aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text 2>/dev/null || echo "")
if [ -n "$POLICY_ARN" ] && [ "$POLICY_ARN" != "None" ]; then
  aws iam detach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true
  aws iam delete-policy --policy-arn "$POLICY_ARN" 2>/dev/null || true
fi
aws iam delete-group --group-name "$GROUP_NAME" 2>/dev/null || true

# 로컬 파일 정리
rm -rf ./student-keys

echo ""
echo "========================================="
echo "  ✅ 학생 IAM 사용자, 그룹, 정책 전부 삭제 완료"
echo "  ✅ student-keys/ 폴더 삭제 완료"
echo "========================================="
