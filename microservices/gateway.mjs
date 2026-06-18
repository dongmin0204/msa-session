import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { serve } from '@hono/node-server';

// ============================================================
//  API Gateway — MSA의 핵심 패턴!
//
//  클라이언트는 이 게이트웨이 하나만 바라봅니다.
//  게이트웨이가 요청 경로를 보고, 올바른 서비스로 라우팅합니다.
//
//   /api/catalog/*  →  Catalog Service (port 3001)
//   /api/orders/*   →  Order Service   (port 3002)
// ============================================================

const CATALOG_URL = process.env.CATALOG_URL || 'http://localhost:3001';
const ORDER_URL   = process.env.ORDER_URL   || 'http://localhost:3002';

const app = new Hono();
app.use('*', cors());

async function proxy(targetBase, c) {
  const url = new URL(c.req.url);
  const target = `${targetBase}${url.pathname}${url.search}`;

  try {
    const resp = await fetch(target, {
      method: c.req.method,
      headers: c.req.raw.headers,
      body: ['GET', 'HEAD'].includes(c.req.method) ? undefined : c.req.raw.body,
      duplex: 'half',
    });

    return new Response(resp.body, {
      status: resp.status,
      headers: resp.headers,
    });
  } catch {
    return c.json(
      { message: '서비스에 연결할 수 없습니다. 해당 서비스가 실행 중인지 확인하세요.' },
      503
    );
  }
}

app.all('/api/catalog/*', (c) => proxy(CATALOG_URL, c));
app.all('/api/orders/*',  (c) => proxy(ORDER_URL, c));

const PORT = process.env.GATEWAY_PORT || 4000;
serve({ fetch: app.fetch, port: Number(PORT) }, () => {
  console.log('');
  console.log('🌐 API Gateway running on http://localhost:' + PORT);
  console.log('');
  console.log('   /api/catalog/*  →  ' + CATALOG_URL);
  console.log('   /api/orders/*   →  ' + ORDER_URL);
  console.log('');
});
