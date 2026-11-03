# Design: Ghost Guestbook

## Overview
Ghost Guestbook is the skeleton with one collection, `entries`, and a small,
data-driven UI addition for mood emoji. The architecture is the skeleton's,
unchanged (`aws-architecture.md`):

```
Browser ──► CloudFront ──► S3 (private, OAC)            static frontend
                 └── /api/* ──► API Gateway (HTTP API) ──► Lambda ──► DynamoDB
Alarms + budget ──► SNS ──► email
```

Its own account (id in `.local/apps/ghost-guestbook.json`, gitignored),
profile `kw-ghost-guestbook`, region us-east-1.

## Reused from the skeleton as-is
- `api/handler.mjs` and `api/lib/collections.mjs`: routing, validation (declared
  fields only, types, `maxLength`, select options, 8 KB body limit), CRUD,
  `/api/health`, logging without bodies. No API code changes.
- `infra/*.tf`: site, API, data, alerts, outputs. No infrastructure changes.
  The `COLLECTIONS` env var is generated from `app.config.json`.
- `src/lib/api.js`, `src/main.jsx`, the ghost theme block in `src/index.css`.
- The pipeline scripts.

## Data: `app.config.json`
```json
"collections": [
  {
    "name": "entries",
    "label": "Messages from beyond",
    "itemLabel": "message",
    "titleField": "author",
    "fields": [
      { "name": "author",  "label": "Your name", "type": "text",     "required": true, "maxLength": 60 },
      { "name": "message", "label": "Message",   "type": "textarea", "required": true, "maxLength": 500 },
      { "name": "mood",    "label": "Mood",      "type": "select",   "required": true,
        "options": ["eerie", "friendly", "restless"],
        "icons": { "eerie": "👻", "friendly": "😊👻", "restless": "🌀👻" } }
    ]
  }
]
```
- The mood-to-emoji mapping lives in the config as an optional `icons` map on
  the select field, so the mood names are not duplicated in code
  (`frontend.md`). `parseCollections` ignores unknown keys, so the Lambda
  accepts it unchanged; it adds about 80 bytes to the `COLLECTIONS` env var
  (well under the 3 KB guideline).
- `name` stays `ghost-guestbook` forever (it names every AWS resource).

### Key shape and access pattern
- Item: `pk = C#entries`, `sk = <time-sortable id>`, attributes `id`, `author`,
  `message`, `mood`, `createdAt`, `updatedAt`.
- "Newest 50 first" = `Query pk = C#entries, ScanIndexForward = false,
  Limit = 50`, which the skeleton handler already does. No GSI, no Scan.

## API (unchanged)
| Method | Path | Use here |
|---|---|---|
| GET | `/api/health` | health badge, smoke test |
| GET | `/api/entries` | list newest 50 |
| POST | `/api/entries` | sign the guestbook |
| GET, PUT, DELETE | `/api/entries/{id}` | served by the skeleton, see Open question |

Validation errors return `400 { error: "validation_failed", fields }`; the UI
shows the field messages.

## UI changes (`apps/ghost-guestbook/src/` only)
`components/CollectionPanel.jsx` (the app's copy):
1. **Mood emoji (generic):** for each field of type `select` that has `icons`,
   the item card shows `icons[value]` (fallback 👻) before the title, inside
   `<span role="img" aria-label="Mood: eerie">`, using the field's label in the
   accessible name. The form's `<option>`s show `icon option`.
2. **Loading state:** the list shows "Summoning messages..." until the first
   load finishes; empty and error states stay as they are (`role="alert"`).
3. **Subtle motion:** the emoji gets a slow float animation (Tailwind
   `motion-safe:` variant only), so reduced-motion users see it still.

`App.jsx` keeps the layout; copy stays from `app.config.json`.

Theme: `ghost` (existing tokens: surface `#0b0d17`, ink `#eef0ff`, muted
`#9aa3c7`, accent `#a78bfa`); all meet WCAG AA against surface and panel.

## Deployment
First apply is the full stack into the empty account (expected: creates only).
Then Publish, then verify `/api/health` and one POST plus GET on
`/api/entries` through the site URL.

## Open question
The skeleton serves PUT and DELETE on every collection and shows a Delete
button on each item. Because the API is public and unauthenticated, any
visitor could delete any message. Options:
- **A. Keep the skeleton behavior** (no API change; fine for a demo).
- **B. Make entries append-only:** hide Delete in the UI and reject PUT/DELETE
  for `entries` in the handler (a small, app-only API change with a config flag
  such as `"appendOnly": true` checked in `api/lib/collections.mjs`).
**Decision (human, checkpoint 3): A.** It is a demo; the skeleton behavior stays.
