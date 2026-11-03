# Deployment

Every app ships the same way. Run everything from the repo root.

| Change | Command |
|---|---|
| New app | `.\scripts\New-App.ps1 -Name <name> -Description "<line>" -Theme <theme>` |
| Infrastructure, Lambda code, or `app.config.json` collections | `Plan-App.ps1`, present, explicit yes, `Apply-App.ps1` |
| Frontend only (`src/`, `index.html`, `public/`) | `.\scripts\Publish-App.ps1 -Name <name>` |
| Both | Plan, yes, Apply, then Publish |

## What Publish does
1. `npm run build` in `apps/<name>`.
2. Uploads `dist/assets/*` with `public,max-age=31536000,immutable` and
   everything else (`index.html`, favicon) with `no-cache`.
3. Invalidates CloudFront `/*`.
4. Smoke test: the site returns the app shell and `/api/health` returns
   `"ok":true` (retries for about 2 minutes; a brand-new distribution can take
   a few minutes to answer).
5. Sends a crew alert email.

## Before saying "deployed"
- Publish printed `Site OK` and `API OK`, or you checked
  `<site_url>/api/health` yourself.
- For API changes, call the changed endpoint once through `<site_url>/api/...`.
- Report the site URL from `.local/apps/<name>.json` (`outputs.site_url`).

## Local development
```powershell
cd apps\<name>
$env:API_PROXY_TARGET = "<site_url>"   # Vite proxies /api to the deployed API
npm run dev
```

## Never
- Upload with ad-hoc `aws s3 cp` to someone else's bucket or account.
- Deploy from `skeleton/` (it is a template, not an app).
- Add a CI deploy workflow; the scripts are the deploy path.
