#!/bin/bash

# 사용법: ./scripts/test-api.sh [BASE_URL]
# 기본값: http://localhost:5173 (모놀리식 모드)
# AWS:   ./scripts/test-api.sh https://xxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod

BASE_URL="${1:-http://localhost:5173}"

FAILED=0

print_json() {
  python3 -c 'import json, sys; print(json.dumps(json.loads(sys.argv[1]), ensure_ascii=False, indent=2))' "$1" 2>/dev/null || printf '%s\n' "$1"
}

request() {
  local label="$1"
  local method="$2"
  local path="$3"
  local data="${4:-}"
  local response
  local body
  local status

  echo ""
  echo "$label"

  if [ "$method" = "POST" ]; then
    response=$(curl -sS -w '\n%{http_code}' -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -d "$data")
  else
    response=$(curl -sS -w '\n%{http_code}' "$BASE_URL$path")
  fi

  status=$(printf '%s' "$response" | tail -n 1)
  body=$(printf '%s' "$response" | sed '$d')

  if [ -n "$body" ]; then
    print_json "$body"
  else
    echo "(empty response)"
  fi

  if [ "$status" -lt 200 ] || [ "$status" -ge 300 ] || [ -z "$body" ]; then
    echo "❌ 실패: HTTP $status"
    FAILED=1
  else
    echo "✅ 성공: HTTP $status"
  fi
}

echo ""
echo "🧪 API 테스트 — $BASE_URL"
echo "========================================="

request "1. 카테고리 조회" GET /api/catalog/categories
request "2. 상품 목록 조회" GET /api/catalog/items
request "3. 상품 상세 조회 (아메리카노)" GET /api/catalog/items/1
request "4. 주문 생성" POST /api/orders '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}'

echo ""
echo "========================================="
if [ "$FAILED" -eq 0 ]; then
  echo "✅ 테스트 완료"
else
  echo "❌ 테스트 실패"
  exit 1
fi
