// ============================================================
//  Catalog Service (AWS Lambda + DynamoDB)
//  카테고리, 상품, 옵션 조회만 담당
//  주문(Order)에 대해 아무것도 모릅니다
// ============================================================

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, GetCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.CATALOG_TABLE;

const headers = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

async function queryByPK(pk) {
  const { Items } = await ddb.send(new QueryCommand({
    TableName: TABLE,
    KeyConditionExpression: 'PK = :pk',
    ExpressionAttributeValues: { ':pk': pk },
  }));
  return Items || [];
}

export const handler = async (event) => {
  const path = event.path || event.rawPath || '';

  // GET /api/catalog/categories
  if (path === '/api/catalog/categories') {
    const items = await queryByPK('CATEGORY');
    const categories = items.map(i => i.name);
    return { statusCode: 200, headers, body: JSON.stringify({ categories }) };
  }

  // GET /api/catalog/items/:id
  const itemMatch = path.match(/^\/api\/catalog\/items\/(\d+)$/);
  if (itemMatch) {
    const { Item } = await ddb.send(new GetCommand({
      TableName: TABLE,
      Key: { PK: 'ITEM', SK: `ITEM#${itemMatch[1]}` },
    }));
    if (!Item) return { statusCode: 404, headers, body: JSON.stringify({ message: '상품을 찾을 수 없어요' }) };
    const { PK, SK, ...item } = Item;
    return { statusCode: 200, headers, body: JSON.stringify({ item }) };
  }

  // GET /api/catalog/items
  if (path === '/api/catalog/items') {
    const items = (await queryByPK('ITEM')).map(({ PK, SK, optionIds, ...rest }) => rest);
    return { statusCode: 200, headers, body: JSON.stringify({ items }) };
  }

  // GET /api/catalog/options
  if (path === '/api/catalog/options') {
    const options = (await queryByPK('OPTION')).map(({ PK, SK, ...rest }) => rest);
    return { statusCode: 200, headers, body: JSON.stringify({ options }) };
  }

  return { statusCode: 404, headers, body: JSON.stringify({ message: 'Not Found' }) };
};
