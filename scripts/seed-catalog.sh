#!/bin/bash
set -e

# ============================================================
#  CatalogTable에 초기 데이터 투입
#  사용법: ./scripts/seed-catalog.sh [스택이름]
# ============================================================

STACK_NAME="${1:-msa-coffee-hands-on}"
REGION="ap-northeast-2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TABLE=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CatalogTableName`].OutputValue' \
  --output text --region "$REGION")

echo "📦 CatalogTable 시드: $TABLE"
CATALOG_TABLE="$TABLE" node "$SCRIPT_DIR/seed-catalog.mjs"
