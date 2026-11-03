// Pure request logic for the skeleton API: routing, config parsing, input
// validation, ids. No AWS SDK imports here, so it runs anywhere.

const RESERVED = new Set(['pk', 'sk', 'id', 'createdAt', 'updatedAt'])
const FIELD_TYPES = new Set(['text', 'textarea', 'number', 'boolean', 'select', 'url', 'email'])
const NAME_RE = /^[a-z][a-z0-9-]{0,39}$/
const FIELD_RE = /^[a-zA-Z][a-zA-Z0-9_]{0,39}$/
const ID_RE = /^[a-z0-9]{1,64}$/
export const MAX_BODY_BYTES = 8 * 1024

export class BadRequest extends Error {
  constructor(code, fields) {
    super(code)
    this.name = 'BadRequest'
    this.code = code
    this.fields = fields
  }
}

// COLLECTIONS env var (JSON from app.config.json) -> Map(name -> collection).
// A bad config is a deploy-time mistake, so it throws at cold start.
export function parseCollections(raw) {
  const list = JSON.parse(raw ?? '[]')
  if (!Array.isArray(list)) throw new Error('COLLECTIONS must be a JSON array')
  const map = new Map()
  for (const c of list) {
    if (!NAME_RE.test(c?.name ?? '')) throw new Error(`Invalid collection name: ${c?.name}`)
    if (!Array.isArray(c.fields) || c.fields.length === 0) throw new Error(`Collection ${c.name} needs fields`)
    for (const f of c.fields) {
      if (!FIELD_RE.test(f?.name ?? '') || RESERVED.has(f.name)) throw new Error(`Invalid field name: ${c.name}.${f?.name}`)
      if (!FIELD_TYPES.has(f.type)) throw new Error(`Invalid field type: ${c.name}.${f.name} (${f.type})`)
      if (f.type === 'select' && !(Array.isArray(f.options) && f.options.length)) throw new Error(`Select field needs options: ${c.name}.${f.name}`)
    }
    map.set(c.name, c)
  }
  return map
}

// /api/health, /api/<collection>, /api/<collection>/<id>
export function matchRoute(rawPath) {
  const path = (rawPath || '/').replace(/\/+$/, '') || '/'
  if (path === '/api/health') return { kind: 'health' }
  const m = /^\/api\/([^/]+)(?:\/([^/]+))?$/.exec(path)
  if (!m) return { kind: 'unknown' }
  const [, collection, id] = m
  if (!NAME_RE.test(collection)) return { kind: 'unknown' }
  if (id !== undefined && !ID_RE.test(id)) return { kind: 'unknown' }
  return { kind: 'collection', collection, id }
}

export function parseBody(event) {
  const raw = event.body ?? ''
  const text = event.isBase64Encoded ? Buffer.from(raw, 'base64').toString('utf8') : raw
  if (Buffer.byteLength(text, 'utf8') > MAX_BODY_BYTES) throw new BadRequest('payload_too_large')
  try {
    return JSON.parse(text || '{}')
  } catch {
    throw new BadRequest('invalid_json')
  }
}

function defaultMax(field) {
  return field.type === 'textarea' ? 2000 : 200
}

function checkValue(field, value) {
  switch (field.type) {
    case 'number':
      return typeof value === 'number' && Number.isFinite(value) ? null : 'must be a number'
    case 'boolean':
      return typeof value === 'boolean' ? null : 'must be true or false'
    case 'select':
      return field.options.includes(value) ? null : `must be one of: ${field.options.join(', ')}`
    default: {
      if (typeof value !== 'string') return 'must be text'
      const max = field.maxLength ?? defaultMax(field)
      if (value.length > max) return `must be at most ${max} characters`
      if (field.type === 'url' && !/^https?:\/\/\S+$/i.test(value)) return 'must be an http(s) URL'
      if (field.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) return 'must be an email address'
      return null
    }
  }
}

// Returns only declared fields; unknown keys are rejected, never stored.
// partial = true for updates (required fields may be omitted).
export function validateItem(collection, body, { partial = false } = {}) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw new BadRequest('validation_failed', { _: 'body must be a JSON object' })
  }
  const errors = {}
  const value = {}
  const known = new Map(collection.fields.map((f) => [f.name, f]))
  for (const key of Object.keys(body)) {
    if (!known.has(key)) errors[key] = 'is not a field of this collection'
  }
  for (const field of collection.fields) {
    let v = body[field.name]
    if (typeof v === 'string') v = v.trim()
    const missing = v === undefined || v === null || v === ''
    if (missing) {
      if (field.required && !partial) errors[field.name] = 'is required'
      continue
    }
    const problem = checkValue(field, v)
    if (problem) errors[field.name] = problem
    else value[field.name] = v
  }
  if (Object.keys(errors).length) throw new BadRequest('validation_failed', errors)
  if (partial && Object.keys(value).length === 0) {
    throw new BadRequest('validation_failed', { _: 'no fields to update' })
  }
  return value
}

// Time-sortable id: 9 chars of base36 milliseconds + 8 random base36 chars.
// Sorting the sort key descending returns newest first.
export function newId(now = Date.now(), random = crypto.getRandomValues(new Uint32Array(2))) {
  const time = now.toString(36).padStart(9, '0')
  const rand = Array.from(random, (n) => n.toString(36).padStart(7, '0').slice(-4)).join('')
  return time + rand
}

export function toPublic(item) {
  if (!item) return item
  const { pk, sk, ...rest } = item
  return rest
}

export function json(statusCode, body) {
  return {
    statusCode,
    headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
    body: body === undefined ? '' : JSON.stringify(body),
  }
}
