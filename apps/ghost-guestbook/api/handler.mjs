// Generic collection API (API Gateway HTTP API, payload v2, Node.js 22).
//   GET    /api/health
//   GET    /api/{collection}          newest 50 items
//   POST   /api/{collection}          create
//   GET    /api/{collection}/{id}     read
//   PUT    /api/{collection}/{id}     partial update
//   DELETE /api/{collection}/{id}     delete
// Collections and their fields come from app.config.json (COLLECTIONS env var).
// Single-table layout: pk = "C#<collection>", sk = <time-sortable id>.
// The AWS SDK v3 is provided by the Lambda runtime; nothing to bundle.

import { DynamoDBClient } from '@aws-sdk/client-dynamodb'
import {
  DeleteCommand,
  DynamoDBDocumentClient,
  GetCommand,
  PutCommand,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb'
import {
  BadRequest,
  json,
  matchRoute,
  newId,
  parseBody,
  parseCollections,
  toPublic,
  validateItem,
} from './lib/collections.mjs'

const db = DynamoDBDocumentClient.from(new DynamoDBClient({}))
const TABLE = process.env.TABLE_NAME
const APP_NAME = process.env.APP_NAME
const COLLECTIONS = parseCollections(process.env.COLLECTIONS)

export async function handler(event) {
  const method = event.requestContext?.http?.method ?? 'GET'
  const route = matchRoute(event.rawPath)

  try {
    if (route.kind === 'health') {
      return json(200, { ok: true, app: APP_NAME, time: new Date().toISOString() })
    }
    const collection = route.kind === 'collection' ? COLLECTIONS.get(route.collection) : undefined
    if (!collection) return json(404, { error: 'not_found' })

    const pk = `C#${collection.name}`

    if (!route.id) {
      if (method === 'GET') {
        const out = await db.send(new QueryCommand({
          TableName: TABLE,
          KeyConditionExpression: 'pk = :pk',
          ExpressionAttributeValues: { ':pk': pk },
          ScanIndexForward: false,
          Limit: 50,
        }))
        return json(200, { items: (out.Items ?? []).map(toPublic) })
      }
      if (method === 'POST') {
        const value = validateItem(collection, parseBody(event))
        const now = new Date().toISOString()
        const id = newId()
        const item = { pk, sk: id, id, ...value, createdAt: now, updatedAt: now }
        await db.send(new PutCommand({
          TableName: TABLE,
          Item: item,
          ConditionExpression: 'attribute_not_exists(pk)',
        }))
        return json(201, toPublic(item))
      }
      return json(405, { error: 'method_not_allowed' })
    }

    const key = { pk, sk: route.id }

    if (method === 'GET') {
      const out = await db.send(new GetCommand({ TableName: TABLE, Key: key }))
      return out.Item ? json(200, toPublic(out.Item)) : json(404, { error: 'not_found' })
    }
    if (method === 'PUT') {
      const value = validateItem(collection, parseBody(event), { partial: true })
      const names = { '#updatedAt': 'updatedAt' }
      const values = { ':updatedAt': new Date().toISOString() }
      const sets = ['#updatedAt = :updatedAt']
      Object.entries(value).forEach(([field, v], i) => {
        names[`#f${i}`] = field
        values[`:v${i}`] = v
        sets.push(`#f${i} = :v${i}`)
      })
      const out = await db.send(new UpdateCommand({
        TableName: TABLE,
        Key: key,
        UpdateExpression: `SET ${sets.join(', ')}`,
        ConditionExpression: 'attribute_exists(pk)',
        ExpressionAttributeNames: names,
        ExpressionAttributeValues: values,
        ReturnValues: 'ALL_NEW',
      }))
      return json(200, toPublic(out.Attributes))
    }
    if (method === 'DELETE') {
      await db.send(new DeleteCommand({
        TableName: TABLE,
        Key: key,
        ConditionExpression: 'attribute_exists(pk)',
      }))
      return { statusCode: 204, headers: { 'cache-control': 'no-store' }, body: '' }
    }
    return json(405, { error: 'method_not_allowed' })
  } catch (err) {
    if (err instanceof BadRequest) {
      const status = err.code === 'payload_too_large' ? 413 : 400
      return json(status, { error: err.code, fields: err.fields })
    }
    if (err?.name === 'ConditionalCheckFailedException') {
      return json(404, { error: 'not_found' })
    }
    // Log the error type and message only: never request bodies.
    console.error(JSON.stringify({ level: 'error', name: err?.name, message: err?.message, path: event.rawPath, method }))
    return json(500, { error: 'internal_error' })
  }
}
