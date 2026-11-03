# Repository structure

```
kiroween/
├── .kiro/
│   ├── steering/        # rules Kiro follows on every app (this folder)
│   ├── hooks/           # guardrails + crew email alerts
│   └── specs/           # the skeleton's own spec, then one spec per app
├── skeleton/            # THE TEMPLATE. New-App.ps1 copies it to apps/<name>
│   ├── app.config.json  # app definition: name, theme, collections (single source of truth)
│   ├── src/             # React frontend (App.jsx, components/, lib/api.js, index.css)
│   ├── api/             # Lambda: handler.mjs + lib/collections.mjs (pure)
│   └── infra/           # Terraform: site, api, data, alerts, outputs
├── apps/                # the apps built from the skeleton, one folder each
├── platform/org/        # Organization guardrails (the project SCP)
├── scripts/             # the pipeline (PowerShell 5.1)
│   ├── lib/Common.ps1   # shared helpers
│   ├── hooks/           # scripts the Kiro hooks run
│   └── config.example.psd1
├── docs/                # WALKTHROUGH.md (the 20-minute live build)
└── .local/              # GITIGNORED: account records, plan state, active app
```

## Rules
- Never edit `skeleton/` while building an app; change `apps/<name>/`. Promote a
  change back to `skeleton/` only on purpose, when every app should get it.
- Generated, gitignored files: `infra/backend.hcl`, `infra/local.auto.tfvars`,
  `infra/tfplan`, `infra/.build/`, `.local/`, `scripts/config.local.psd1`,
  `node_modules/`, `dist/`. Never commit account ids, emails, or state.
- Pure logic goes in `api/lib/*.mjs`; the handler only routes and calls DynamoDB.
- One spec folder per app in `.kiro/specs/<app-name>/`.
