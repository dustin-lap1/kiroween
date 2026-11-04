// Thin client for the skeleton API. CloudFront routes /api/* to API Gateway,
// so every call is same-origin: no CORS, no API URL in the build.

async function request(path, options = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { 'content-type': 'application/json' },
    ...options,
  })
  if (res.status === 204) return null
  const body = await res.json().catch(() => ({}))
  if (!res.ok) {
    const message = body.error === 'validation_failed'
      ? Object.values(body.fields ?? {}).join(' ')
      : body.error ?? `Request failed (${res.status})`
    throw new Error(message)
  }
  return body
}

export const api = {
  health: () => request('/health'),
  stats: () => request('/stats'),
  list: (collection) => request(`/${collection}`).then((b) => b.items),
  create: (collection, data) =>
    request(`/${collection}`, { method: 'POST', body: JSON.stringify(data) }),
  update: (collection, id, data) =>
    request(`/${collection}/${id}`, { method: 'PUT', body: JSON.stringify(data) }),
  remove: (collection, id) => request(`/${collection}/${id}`, { method: 'DELETE' }),
}
