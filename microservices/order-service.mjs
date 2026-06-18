import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { serve } from '@hono/node-server';

const app = new Hono();
app.use('*', cors());

// ============================================================
//  Order Service — 주문만 담당
//  이 서비스는 카탈로그(Catalog)에 대해 아무것도 모릅니다.
//  → Catalog Service가 죽어도 이미 받은 주문은 조회 가능!
//  → 이 서비스가 죽어도 메뉴 조회는 정상 동작!
// ============================================================

const orders = new Map();

app.post('/api/orders', async (c) => {
  const body = await c.req.json();

  if (!body.items || body.items.length === 0) {
    return c.json({ message: '잘못된 주문이에요' }, 400);
  }

  const orderId = crypto.randomUUID().slice(0, 24);
  orders.set(orderId, body);
  return c.json({ orderId });
});

app.get('/api/orders/:orderId', (c) => {
  const order = orders.get(c.req.param('orderId'));
  if (!order) return c.json({ message: '주문을 찾을 수 없어요' }, 404);
  return c.json({ order });
});

const PORT = process.env.PORT || 3002;
serve({ fetch: app.fetch, port: Number(PORT) }, () => {
  console.log(`📦 Order Service running on http://localhost:${PORT}`);
});
