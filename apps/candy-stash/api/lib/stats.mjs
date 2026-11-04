// Pure logic for GET /api/stats (no AWS SDK imports).
// Each stat sums one number field across every item of one collection.

export const STATS = [
  { collection: 'candy', field: 'quantity', total: 'candyPieces', count: 'candyItems' },
  { collection: 'visitors', field: 'groupSize', total: 'visitors', count: 'visitorGroups' },
]

// Safety cap so a huge collection cannot push the Lambda past its timeout.
export const MAX_PAGES = 20

// Sums a numeric field; missing or non-numeric values count as 0.
export function sumField(items, field) {
  let total = 0
  for (const item of items ?? []) {
    const v = item?.[field]
    if (typeof v === 'number' && Number.isFinite(v)) total += v
  }
  return total
}
