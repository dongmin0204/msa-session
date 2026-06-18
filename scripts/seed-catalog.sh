#!/bin/bash
set -e

# ============================================================
#  CatalogTable에 초기 데이터 투입
#  deploy-infra.sh에서 자동 호출됨
# ============================================================

STACK_NAME="msa-coffee-hands-on"
REGION="ap-northeast-2"

TABLE=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --query 'Stacks[0].Outputs[?OutputKey==`CatalogTableName`].OutputValue' \
  --output text --region "$REGION")

echo "📦 CatalogTable($TABLE)에 데이터 투입 중..."

# Categories
for name in "커피" "음료" "디저트"; do
  aws dynamodb put-item --table-name "$TABLE" --region "$REGION" --item "{
    \"PK\": {\"S\": \"CATEGORY\"}, \"SK\": {\"S\": \"CAT#$name\"}, \"name\": {\"S\": \"$name\"}
  }" 2>/dev/null
done
echo "  ✅ 카테고리 3개"

# Items
node -e "
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, PutCommand } = require('@aws-sdk/lib-dynamodb');
const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({ region: '$REGION' }));

const items = [
  { id: 1, category: '커피',   title: '아메리카노', description: '깊고 진한 에스프레소가 선사하는 깔끔한 풍미!',         price: 4500, iconImg: '/images/coffee.png',         optionIds: [1, 2, 3] },
  { id: 2, category: '음료',   title: '자몽티',     description: '상큼한 자몽의 싱그러움을 한 잔에!',                   price: 6000, iconImg: '/images/grapefruit_tea.png', optionIds: [1] },
  { id: 3, category: '커피',   title: '카페라떼',   description: '부드러운 우유와 에스프레소가 어우러진 조화로운 맛.',     price: 5000, iconImg: '/images/coffeelatte.png',    optionIds: [1, 3, 2] },
  { id: 4, category: '음료',   title: '아이스티',   description: '상쾌한 달콤함이 가득한 한 잔!',                       price: 4500, iconImg: '/images/ice_tea.png',        optionIds: [] },
  { id: 5, category: '음료',   title: '버블티',     description: '쫀득한 타피오카 펄과 달콤한 밀크티의 환상적인 만남!',   price: 6000, iconImg: '/images/bubble_tea.png',     optionIds: [4] },
  { id: 6, category: '디저트', title: '붕어빵',     description: '바삭한 껍과 달콤한 팥이 가득한 속!',                   price: 1800, iconImg: '/images/bungeobbang.png',    optionIds: [5] },
  { id: 7, category: '디저트', title: '와플',       description: '바삭하고 촉촉한 와플 위에 달콤한 시럽과 토핑까지!',     price: 3300, iconImg: '/images/waffle.png',         optionIds: [6] },
  { id: 8, category: '디저트', title: '샌드위치',   description: '든든하게 즐기는 한 끼! 신선한 재료를 가득 담았어요.',   price: 4100, iconImg: '/images/sandwich.png',       optionIds: [6, 7] },
];

const options = [
  { id: 1, name: '온도',     type: 'grid',   col: 2, labels: ['HOT', 'ICE'], icons: ['icon-emoji-fire', 'icon-snow'] },
  { id: 2, name: '진하기',   type: 'select', labels: ['연하게', '샷 추가'], prices: [0, 500] },
  { id: 3, name: '추가옵션', type: 'list',   maxCount: 2, minCount: 0, labels: ['설탕시럽 추가', '바닐라 시럽 추가', '휘핑크림 추가'], prices: [0, 500, 500] },
  { id: 4, name: '당도',     type: 'select', labels: ['50%', '100%', '125%', '150%'], prices: [0, 0, 0, 0] },
  { id: 5, name: '속재료',   type: 'grid',   col: 3, labels: ['팥', '슈크림', '고구마'], icons: ['/images/icon-bean.svg', 'icon-cream-whtie', 'icon-sweet-potato-half'] },
  { id: 6, name: '굽기',     type: 'select', labels: ['보통', '바싹하게'], prices: [0, 500] },
  { id: 7, name: '토핑',     type: 'list',   maxCount: 3, minCount: 1, labels: ['치즈', '양상추', '계란후라이', '토마토', '파인애플', '베이컨'], prices: [500, 500, 1000, 500, 500, 1500] },
];

(async () => {
  for (const item of items) {
    await ddb.send(new PutCommand({ TableName: '$TABLE', Item: { PK: 'ITEM', SK: 'ITEM#' + item.id, ...item } }));
  }
  console.log('  ✅ 상품 ' + items.length + '개');
  for (const opt of options) {
    await ddb.send(new PutCommand({ TableName: '$TABLE', Item: { PK: 'OPTION', SK: 'OPT#' + opt.id, ...opt } }));
  }
  console.log('  ✅ 옵션 ' + options.length + '개');
})();
" 2>/dev/null

echo "✅ CatalogTable 시드 완료"
