#!/bin/bash

# 사용법: ./scripts/test-api.sh [BASE_URL]
# 기본값: http://localhost:5173 (모놀리식 모드)
# AWS:   ./scripts/test-api.sh https://xxxxx.execute-api.ap-northeast-2.amazonaws.com/Prod

BASE_URL="${1:-http://localhost:5173}"

echo ""
echo "🧪 API 테스트 — $BASE_URL"
echo "========================================="

echo ""
echo "1. 카테고리 조회"
curl -s "$BASE_URL/api/catalog/categories" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/api/catalog/categories"

echo ""
echo ""
echo "2. 상품 목록 조회"
curl -s "$BASE_URL/api/catalog/items" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/api/catalog/items"

echo ""
echo ""
echo "3. 상품 상세 조회 (아메리카노)"
curl -s "$BASE_URL/api/catalog/items/1" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/api/catalog/items/1"

echo ""
echo ""
echo "4. 주문 생성"
RESULT=$(curl -s -X POST "$BASE_URL/api/orders" \
  -H "Content-Type: application/json" \
  -d '{"totalPrice":4500,"items":[{"itemId":1,"quantity":1,"options":[{"optionId":1,"labels":["HOT"]}]}]}')
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

echo ""
echo "========================================="
echo "✅ 테스트 완료"
