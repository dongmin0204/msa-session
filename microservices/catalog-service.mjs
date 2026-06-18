import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { serve } from '@hono/node-server';

const app = new Hono();
app.use('*', cors());

// ============================================================
//  Catalog Service — 상품 데이터만 담당
//  이 서비스는 주문(Order)에 대해 아무것도 모릅니다.
// ============================================================

const CATEGORIES = ['커피', '음료', '디저트'];

const ITEMS = [
  { id: 1, category: '커피',   title: '아메리카노', description: '깊고 진한 에스프레소가 선사하는 깔끔한 풍미!',         price: 4500, iconImg: '/images/coffee.png',         optionIds: [1, 2, 3] },
  { id: 2, category: '음료',   title: '자몽티',     description: '상큼한 자몽의 싱그러움을 한 잔에!',                   price: 6000, iconImg: '/images/grapefruit_tea.png', optionIds: [1] },
  { id: 3, category: '커피',   title: '카페라떼',   description: '부드러운 우유와 에스프레소가 어우러진 조화로운 맛.',     price: 5000, iconImg: '/images/coffeelatte.png',    optionIds: [1, 3, 2] },
  { id: 4, category: '음료',   title: '아이스티',   description: '상쾌한 달콤함이 가득한 한 잔!',                       price: 4500, iconImg: '/images/ice_tea.png',        optionIds: [] },
  { id: 5, category: '음료',   title: '버블티',     description: '쫀득한 타피오카 펄과 달콤한 밀크티의 환상적인 만남!',   price: 6000, iconImg: '/images/bubble_tea.png',     optionIds: [4] },
  { id: 6, category: '디저트', title: '붕어빵',     description: '바삭한 껍과 달콤한 팥이 가득한 속!',                   price: 1800, iconImg: '/images/bungeobbang.png',    optionIds: [5] },
  { id: 7, category: '디저트', title: '와플',       description: '바삭하고 촉촉한 와플 위에 달콤한 시럽과 토핑까지!',     price: 3300, iconImg: '/images/waffle.png',         optionIds: [6] },
  { id: 8, category: '디저트', title: '샌드위치',   description: '든든하게 즐기는 한 끼! 신선한 재료를 가득 담았어요.',   price: 4100, iconImg: '/images/sandwich.png',       optionIds: [6, 7] },
];

const OPTIONS = [
  { id: 1, name: '온도',       type: 'grid',   col: 2, labels: ['HOT', 'ICE'], icons: ['icon-emoji-fire', 'icon-snow'] },
  { id: 2, name: '진하기',     type: 'select', labels: ['연하게', '샷 추가'], prices: [0, 500] },
  { id: 3, name: '추가옵션',   type: 'list',   maxCount: 2, minCount: 0, labels: ['설탕시럽 추가', '바닐라 시럽 추가', '휘핑크림 추가'], prices: [0, 500, 500] },
  { id: 4, name: '당도',       type: 'select', labels: ['50%', '100%', '125%', '150%'], prices: [0, 0, 0, 0] },
  { id: 5, name: '속재료',     type: 'grid',   col: 3, labels: ['팥', '슈크림', '고구마'], icons: ['/images/icon-bean.svg', 'icon-cream-whtie', 'icon-sweet-potato-half'] },
  { id: 6, name: '굽기',       type: 'select', labels: ['보통', '바싹하게'], prices: [0, 500] },
  { id: 7, name: '토핑',       type: 'list',   maxCount: 3, minCount: 1, labels: ['치즈', '양상추', '계란후라이', '토마토', '파인애플', '베이컨'], prices: [500, 500, 1000, 500, 500, 1500] },
];

app.get('/api/catalog/categories', (c) => c.json({ categories: CATEGORIES }));

app.get('/api/catalog/items', (c) => {
  const items = ITEMS.map(({ optionIds, ...rest }) => rest);
  return c.json({ items });
});

app.get('/api/catalog/items/:id', (c) => {
  const item = ITEMS.find((i) => i.id === Number(c.req.param('id')));
  if (!item) return c.json({ message: '상품을 찾을 수 없어요' }, 404);
  return c.json({ item });
});

app.get('/api/catalog/options', (c) => c.json({ options: OPTIONS }));

const PORT = process.env.PORT || 3001;
serve({ fetch: app.fetch, port: Number(PORT) }, () => {
  console.log(`☕ Catalog Service running on http://localhost:${PORT}`);
});
