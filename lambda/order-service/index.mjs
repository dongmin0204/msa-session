// ============================================================
//  Order Service (AWS Lambda + DynamoDB)
//  주문 생성/조회만 담당
//  카탈로그(Catalog)에 대해 아무것도 모릅니다
// ============================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, GetCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.ORDER_TABLE;

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

export const handler = async (event) => {
  const path = event.path || event.rawPath || '';
  const method = event.httpMethod || event.requestContext?.http?.method || 'GET';

  // POST /api/orders
  if (path === '/api/orders' && method === 'POST') {
    const body = JSON.parse(event.body || '{}');

    if (!body.items || body.items.length === 0) {
      return { statusCode: 400, headers, body: JSON.stringify({ message: '잘못된 주문이에요' }) };
    }

    const orderId = crypto.randomUUID().slice(0, 24);

    await ddb.send(new PutCommand({
      TableName: TABLE,
      Item: { orderId, ...body },
    }));

    return { statusCode: 200, headers, body: JSON.stringify({ orderId }) };
  }

  // GET /api/orders/:orderId
  const orderMatch = path.match(/^\/api\/orders\/(.+)$/);
  if (orderMatch && method === 'GET') {
    const { Item } = await ddb.send(new GetCommand({
      TableName: TABLE,
      Key: { orderId: orderMatch[1] },
    }));

    if (!Item) {
      return { statusCode: 404, headers, body: JSON.stringify({ message: '주문을 찾을 수 없어요' }) };
    }

    return { statusCode: 200, headers, body: JSON.stringify({ order: Item }) };
  }

  return { statusCode: 404, headers, body: JSON.stringify({ message: 'Not Found' }) };
};
