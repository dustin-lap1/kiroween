---
inclusion: fileMatch
fileMatchPattern: "**/app.config.json"
---

# app.config.json rules

`app.config.json` defines an app. Terraform reads it (resource names, the
Lambda's `COLLECTIONS` env var), the Lambda validates every request against
it, and the UI renders a panel per collection from it.

```json
{
  "name": "ghost-guestbook",
  "displayName": "Ghost Guestbook",
  "description": "Leave a message for the spirits.",
  "theme": "ghost",
  "collections": [
    {
      "name": "entries",
      "label": "Messages from beyond",
      "itemLabel": "message",
      "titleField": "author",
      "fields": [
        { "name": "author", "label": "Your name", "type": "text", "required": true, "maxLength": 60 },
        { "name": "message", "label": "Message", "type": "textarea", "required": true, "maxLength": 500 },
        { "name": "mood", "label": "Mood", "type": "select", "options": ["eerie", "friendly", "restless"] }
      ]
    }
  ]
}
```

## Rules (the Lambda enforces them at cold start)
- `name`: never change it after the first apply (it names every AWS resource;
  changing it replaces the whole stack).
- `theme`: `pumpkin`, `ghost`, `slime`, or `blood` (add more in `src/index.css`).
- Collection `name`: `^[a-z][a-z0-9-]{0,39}$`; it is the URL segment `/api/<name>`.
- Field `name`: `^[a-zA-Z][a-zA-Z0-9_]{0,39}$`, not `pk`, `sk`, `id`,
  `createdAt`, or `updatedAt`.
- Field `type`: `text`, `textarea`, `number`, `boolean`, `select`, `url`, `email`.
  `select` needs `options`. Strings default to 200 chars (`textarea` 2000);
  set `maxLength` to tighten.
- Removing a field does not delete stored data; the API just stops returning
  and accepting it.
- Keep the whole `collections` array under about 3 KB (it travels in a Lambda
  environment variable, 4 KB limit).

## Shipping a config change
Collections and fields are part of the Lambda configuration: Plan-App, the
human's yes, Apply-App, then Publish-App for the UI.
