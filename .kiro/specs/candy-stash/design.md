# Design: Candy Stash

## Reused from the skeleton as-is
- Architecture: CloudFront -> S3 (OAC) for the site, `/api/*` -> HTTP API ->
  one Lambda (Node.js 22, arm64) -> one DynamoDB table. Alarms, budget, SNS.
- Generic collection CRUD in `api/handler.mjs` (`/api/candy`, `/api/visitors`).
- `infra/`: **no changes.** The Lambda role already allows `dynamodb:Query` on
  the table, and the `ANY /api/{proxy+}` route already reaches the Lambda.
- `src/lib/api.js` request helper, theme tokens in `src/index.css` (pumpkin).

## app.config.json

```json
{
  "name": "candy-stash",
  "displayName": "Candy Stash",
  "description": "Count the loot and the little monsters who came knocking.",
  "theme": "pumpkin",
  "collections": [
    {
      "name": "candy", "label": "The stash", "itemLabel": "candy", "titleField": "name",
      "fields": [
        { "name": "name", "label": "Candy", "type": "text", "required": true, "maxLength": 60 },
        { "name": "kind", "label": "Kind", "type": "select", "required": true,
          "options": ["chocolate", "gummy", "sour", "hard"] },
        { "name": "quantity", "label": "Pieces", "type": "number", "required": true, "integer": true, "min": 1, "max": 100000 },
        { "name": "nutFree", "label": "Nut free", "type": "boolean" }
      ]
    },
    {
      "name": "visitors", "label": "Trick-or-treaters", "itemLabel": "visitor group", "titleField": "costume",
      "fields": [
        { "name": "costume", "label": "Costume", "type": "text", "required": true, "maxLength": 80 },
        { "name": "groupSize", "label": "Group size", "type": "number", "required": true, "integer": true, "min": 1, "max": 100 }
      ]
    }
  ]
}
```

## API changes (`apps/candy-stash/api/`)

### Number constraints (pure, `api/lib/collections.mjs`)
The skeleton's `number` check accepts any finite number. Add optional field
keys `integer` (boolean), `min`, and `max` (numbers). `checkValue` rejects a
non-integer when `integer` is true, and values outside `min`/`max`, with a clear
message ("must be a whole number", "must be at least 1"). `parseCollections`
validates that `min`/`max` are numbers when present. Rejects, never coerces.

### `GET /api/stats` (new endpoint, existing key shape)
- **Access pattern:** totals per collection. Uses the existing key shape
  `pk = C#<collection>`: one paginated `Query` per collection with
  `ProjectionExpression` on the summed field, following `LastEvaluatedKey`.
  No Scan, no GSI, no new IAM action.
- **Pure logic** in `api/lib/stats.mjs`: `STATS` definition
  (`candy.quantity -> candyPieces`, `visitors.groupSize -> visitors`) and
  `sumField(items, field)` (ignores missing / non-numeric values).
- **Routing:** `matchRoute` returns `{ kind: 'stats' }` for `/api/stats`
  (checked before collections; `stats` is not a collection name). Only `GET`;
  other methods get `405`.
- **Response:** `{ candyPieces, visitors, candyItems, visitorGroups }`, `no-store`.
- **Cost / scale:** each read reads every item's key and one number. At
  Halloween-night volume (hundreds of items) that is one page per collection,
  well under a cent. A safety cap of 20 pages per collection keeps the Lambda
  inside its 10 s timeout.
- **Alternative considered:** a counter item updated on every create/update/
  delete (`ADD` in an `UpdateItem`). Constant-time reads, but every write path
  must keep it right (including partial updates and deletes), and drift is hard
  to repair. Not worth it at this scale.

## UI changes (`apps/candy-stash/src/`)
- `src/lib/api.js`: add `stats: () => request('/stats')`.
- `src/components/StashTotals.jsx` (new): two big tiles, "Pieces of candy" 🍬
  and "Visitors" 🎃, above the panels. Loading ("Counting..."), error
  (`role="alert"`), `aria-live="polite"` on the numbers. Stacks on narrow
  screens (`grid-cols-1 sm:grid-cols-2`).
- `src/App.jsx`: holds a `statsVersion` counter, renders `<StashTotals
  version={statsVersion} />`, and passes `onChange` to each `CollectionPanel`.
- `src/components/CollectionPanel.jsx`: call `onChange?.()` after a successful
  create or delete; add a list loading state ("Loading...") and keep the empty
  and error states; pass `min`, `max`, and `step` (1 for `integer`) to number
  inputs; scope field ids by collection (`field-<collection>-<field>`) so ids
  stay unique with two panels.

## Theme
`pumpkin`, existing tokens only. No new CSS beyond Tailwind utilities.

## Infra
None. The first apply into the empty account is the full skeleton stack.
