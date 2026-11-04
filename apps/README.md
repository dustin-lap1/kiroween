# Apps built from the skeleton

Each folder here is one app, created with `.\scripts\New-App.ps1` from
`skeleton/`, with its own AWS account and its own spec in
`.kiro/specs/<app-name>/`.

| App | What it shows | Spec |
|---|---|---|
| [`ghost-guestbook`](ghost-guestbook/) | one collection (entries), mood emoji per message, ghost theme | `.kiro/specs/ghost-guestbook/` |
| [`candy-stash`](candy-stash/) | two collections (candy, visitors), number validation, a `GET /api/stats` totals endpoint, pumpkin theme | `.kiro/specs/candy-stash/` |
