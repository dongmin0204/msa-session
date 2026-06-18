#!/bin/bash
set -euo pipefail

# ============================================================
#  진행자 전용 — 학생용 IAM 사용자 + Access Key 생성
#
#  사용법:
#    ./scripts/create-student-keys.sh 3          # 학생 3명분 생성
#    ./scripts/create-student-keys.sh 30         # 학생 30명분 생성
#
#  결과:
#    ./student-keys/ 폴더에 학생별 자격증명 파일 생성
#    student-keys/all-keys.csv  — 전체 목록 (배포용)
# ============================================================

STUDENT_COUNT="${1:-5}"
REGION="ap-northeast-2"
POLICY_NAME="msa-session-student-policy"
GROUP_NAME="msa-session-students"
OUTPUT_DIR="./student-keys"

mkdir -p "$OUTPUT_DIR"

echo ""
echo "========================================="
echo "  🔑 학생용 AWS 자격증명 생성"
echo "  학생 수: ${STUDENT_COUNT}명"
echo "========================================="
echo ""

# 1. 최소 권한 IAM 정책 생성
echo "[1/3] IAM 정책 생성..."

POLICY_DOC='{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "SAMDeploy",
      "Effect": "Allow",
      "Action": [
        "cloudformation:CreateStack",
        "cloudformation:UpdateStack",
        "cloudformation:DeleteStack",
        "cloudformation:DescribeStacks",
        "cloudformation:DescribeStackEvents",
        "cloudformation:GetTemplateSummary",
        "cloudformation:ListStackResources",
        "cloudformation:CreateChangeSet",
        "cloudformation:DescribeChangeSet",
        "cloudformation:ExecuteChangeSet",
        "cloudformation:DeleteChangeSet"
      ],
      "Resource": [
        "arn:aws:cloudformation:'"$REGION"':*:stack/msa-coffee-*/*",
        "arn:aws:cloudformation:'"$REGION"':*:stack/aws-sam-cli-managed-default/*"
      ]
    },
    {
      "Sid": "SAMTransform",
      "Effect": "Allow",
      "Action": "cloudformation:CreateChangeSet",
      "Resource": "arn:aws:cloudformation:'"$REGION"':aws:transform/Serverless-*"
    },
    {
      "Sid": "SAMManagedResources",
      "Effect": "Allow",
      "Action": [
        "cloudformation:GetTemplateSummary",
        "cloudformation:DescribeStacks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Lambda",
      "Effect": "Allow",
      "Action": [
        "lambda:CreateFunction",
        "lambda:UpdateFunctionCode",
        "lambda:UpdateFunctionConfiguration",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:ListTags",
        "lambda:TagResource",
        "lambda:UntagResource",
        "lambda:AddPermission",
        "lambda:RemovePermission"
      ],
      "Resource": "arn:aws:lambda:'"$REGION"':*:function:msa-coffee-*"
    },
    {
      "Sid": "APIGateway",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET",
        "apigateway:POST",
        "apigateway:PUT",
        "apigateway:PATCH",
        "apigateway:DELETE"
      ],
      "Resource": "arn:aws:apigateway:'"$REGION"'::*"
    },
    {
      "Sid": "IAMForLambda",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:GetRolePolicy",
        "iam:PassRole",
        "iam:TagRole",
        "iam:UntagRole"
      ],
      "Resource": "arn:aws:iam::*:role/msa-coffee-*"
    },
    {
      "Sid": "S3SAMArtifacts",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:PutBucketPolicy",
        "s3:GetBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:PutBucketTagging"
      ],
      "Resource": [
        "arn:aws:s3:::aws-sam-cli-managed-*",
        "arn:aws:s3:::aws-sam-cli-managed-*/*",
        "arn:aws:s3:::msa-coffee-*",
        "arn:aws:s3:::msa-coffee-*/*"
      ]
    },
    {
      "Sid": "DynamoDB",
      "Effect": "Allow",
      "Action": [
        "dynamodb:CreateTable",
        "dynamodb:DeleteTable",
        "dynamodb:DescribeTable",
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:TagResource",
        "dynamodb:UntagResource"
      ],
      "Resource": "arn:aws:dynamodb:'"$REGION"':*:table/msa-coffee-*"
    },
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DeleteLogGroup",
        "logs:DescribeLogGroups",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "arn:aws:logs:'"$REGION"':*:log-group:/aws/lambda/msa-coffee-*"
    },
    {
      "Sid": "STSIdentity",
      "Effect": "Allow",
      "Action": "sts:GetCallerIdentity",
      "Resource": "*"
    }
  ]
}'

POLICY_ARN=$(aws iam create-policy \
  --policy-name "$POLICY_NAME" \
  --policy-document "$POLICY_DOC" \
  --query 'Policy.Arn' \
  --output text 2>/dev/null || \
  aws iam list-policies --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text)

echo "  → 정책: $POLICY_ARN"

# 2. IAM 그룹 생성 + 정책 연결
echo "[2/3] IAM 그룹 생성..."
aws iam create-group --group-name "$GROUP_NAME" 2>/dev/null || true
aws iam attach-group-policy --group-name "$GROUP_NAME" --policy-arn "$POLICY_ARN" 2>/dev/null || true
echo "  → 그룹: $GROUP_NAME"

# 3. 학생별 IAM 사용자 + Access Key 생성
echo "[3/3] 학생용 사용자 생성 중..."
echo ""

CSV_FILE="$OUTPUT_DIR/all-keys.csv"
echo "username,access_key_id,secret_access_key" > "$CSV_FILE"

for i in $(seq -w 1 "$STUDENT_COUNT"); do
  USERNAME="msa-student-$i"

  # 사용자 생성
  aws iam create-user --user-name "$USERNAME" 2>/dev/null || true
  aws iam add-user-to-group --user-name "$USERNAME" --group-name "$GROUP_NAME" 2>/dev/null || true

  # 기존 키 삭제 (재실행 대비)
  OLD_KEYS=$(aws iam list-access-keys --user-name "$USERNAME" --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null || echo "")
  for key in $OLD_KEYS; do
    aws iam delete-access-key --user-name "$USERNAME" --access-key-id "$key" 2>/dev/null || true
  done

  # 새 Access Key 생성
  KEY_JSON=$(aws iam create-access-key --user-name "$USERNAME" --output json)
  ACCESS_KEY=$(echo "$KEY_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
  SECRET_KEY=$(echo "$KEY_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")

  # 개별 파일 저장
  cat > "$OUTPUT_DIR/$USERNAME.txt" << EOF
==============================
  $USERNAME
==============================

Codespaces 터미널에 붙여넣기:

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="ap-northeast-2"

또는 aws configure:

AWS Access Key ID:     $ACCESS_KEY
AWS Secret Access Key: $SECRET_KEY
Default region:        ap-northeast-2
Default output:        json

확인: aws sts get-caller-identity
EOF

  # CSV 추가
  echo "$USERNAME,$ACCESS_KEY,$SECRET_KEY" >> "$CSV_FILE"

  echo "  ✅ $USERNAME → $OUTPUT_DIR/$USERNAME.txt"
done

echo ""
echo "========================================="
echo "  ✅ 학생 ${STUDENT_COUNT}명 자격증명 생성 완료!"
echo ""
echo "  📁 개별 파일: $OUTPUT_DIR/msa-student-XX.txt"
echo "  📋 전체 CSV:  $CSV_FILE"
echo ""
echo "  ⚠️  student-keys/ 폴더를 Git에 커밋하지 마세요!"
echo "  ⚠️  세션 후 반드시 ./scripts/10-delete-student-keys.sh 실행"
echo "========================================="
