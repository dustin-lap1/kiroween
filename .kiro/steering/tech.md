# Tech stack

## Frontend (`skeleton/src`, `apps/<name>/src`)
- React 19 (JSX, no TypeScript), Vite 8, Tailwind CSS 4 (`@tailwindcss/vite`)
- Theme tokens in `src/index.css` (`[data-theme]` blocks); components use the
  semantic utilities only (`bg-surface`, `bg-panel`, `text-ink`, `text-muted`,
  `bg-accent`, `text-accent-ink`, `border-edge`, `font-display`)
- Same-origin API: the browser calls `/api/...`; CloudFront routes it to API
  Gateway. No API URL in the build, no CORS.

## Backend (`api/`)
- One Lambda, Node.js 22 (`nodejs22.x`), **arm64**, ESM `.mjs`, payload v2
- AWS SDK v3 comes from the Lambda runtime: never bundle it, no `node_modules`
  in `api/`
- Pure logic in `api/lib/*.mjs` (no SDK imports), the handler wires it to DynamoDB

## Data
- DynamoDB, one table per app, single-table design: `pk = C#<collection>`,
  `sk = <time-sortable id>`; PAY_PER_REQUEST, PITR on, deletion protection on

## Infrastructure
- Terraform >= 1.7 (local binary `C:\Terraform\terraform.exe`, 1.7.5),
  AWS provider ~> 5.80, archive provider for the Lambda zip
- S3 backend per app account (bucket `<name>-tfstate-<account>`, lock table
  `terraform-locks`), generated `backend.hcl` and `local.auto.tfvars`
- Region **us-east-1 only** (enforced by SCPs)

## Tooling
- Windows PowerShell 5.1 scripts in `scripts/` (no pwsh-only syntax: no `??`,
  no ternary, no `-AsHashtable`; use `Invoke-Native` for native commands)
- AWS CLI v2, GitHub CLI (`gh`), Node.js 22+, npm

## Commands
```powershell
.\scripts\New-App.ps1 -Name <name> -Description "<one line>" [-DisplayName "<Name>"] [-Theme pumpkin|ghost|slime|blood]
.\scripts\Plan-App.ps1    -Name <name> [-Target <address>]
.\scripts\Apply-App.ps1   -Name <name>
.\scripts\Publish-App.ps1 -Name <name>
# inside an app folder
npm install; npm run dev; npm run build
```
