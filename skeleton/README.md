# __APP_DISPLAY_NAME__

__APP_DESCRIPTION__

Built from the Skeleton Crew serverless template (`skeleton/` at the repo root).

## What is here

| Path | What it is |
|---|---|
| `app.config.json` | The app definition: name, theme, and the collections the API serves. Terraform, the Lambda, and the UI all read it. |
| `src/` | React 19 + Vite + Tailwind CSS 4 frontend |
| `api/` | One Lambda (Node.js 22): a validated CRUD API over the collections |
| `infra/` | Terraform: S3 + CloudFront, HTTP API + Lambda, DynamoDB, SNS alerts, a cost budget |

## Pipeline (run from the repo root)

```powershell
.\scripts\Plan-App.ps1    -Name __APP_NAME__   # review the plan
.\scripts\Apply-App.ps1   -Name __APP_NAME__   # applies exactly that plan, after you say yes
.\scripts\Publish-App.ps1 -Name __APP_NAME__   # build, upload, invalidate, smoke test
```

## Local development

```powershell
npm install
$env:API_PROXY_TARGET = "<site_url from .local/apps/__APP_NAME__.json>"
npm run dev
```
