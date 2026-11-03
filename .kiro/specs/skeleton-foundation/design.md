# Design: Skeleton foundation

## Overview
```
Browser ──► CloudFront ──► S3 (private, OAC)                  skeleton/src
                 └── /api/* ──► HTTP API ──► Lambda ──► DynamoDB   skeleton/api
Lambda errors alarm + budget ──► SNS ──► email                 skeleton/infra/alerts.tf

Kiro hooks / scripts ──► SNS topic "kiroween-crew-alerts" (crew account) ──► email
```

## Organization
- OU `Kiroween-2026` under the root, with `FullAWSAccess` and the project SCP
  `Kiroween2026Guardrails` (`platform/org/kiroween-guardrails.scp.json`):
  us-east-1 only with no role exemptions; no IAM users or access keys; the
  deployer role and Terraform state are protected from everyone except
  `OrganizationAccountAccessRole`.
- Root SCPs still apply (approved services only, expensive services denied).

## App definition: `app.config.json`
The single source of truth. Terraform `jsondecode`s it for resource names and
passes `collections` to the Lambda as `COLLECTIONS`; the frontend imports it.

## API (`api/handler.mjs`, `api/lib/collections.mjs`)
- `matchRoute`, `parseCollections`, `parseBody`, `validateItem`, `newId`, `toPublic`
  are pure functions (no SDK), testable anywhere.
- Keys: `pk = C#<collection>`, `sk = id`; ids are 9 chars of base36 time plus 8
  random chars, so a descending Query returns newest first.
- Updates use `attribute_exists(pk)`; creates use `attribute_not_exists(pk)`.
  A failed condition returns 404.
- Errors: 400 `validation_failed` with per-field messages, 413
  `payload_too_large`, 404 `not_found`, 405, 500 `internal_error` (logged
  without the body).

## Frontend
- `App.jsx` sets `data-theme` and renders a `CollectionPanel` per collection.
- `CollectionPanel` builds the form from field definitions and calls
  `lib/api.js` (relative `/api` paths).
- Themes are `[data-theme]` blocks of CSS variables mapped to Tailwind tokens
  with `@theme inline`.

## Infrastructure (`infra/`)
| File | Resources |
|---|---|
| `versions.tf` | providers, partial S3 backend, `allowed_account_ids`, default tags |
| `site.tf` | S3 bucket, OAC, SPA rewrite function, CloudFront (S3 + `/api/*` origin), bucket policy |
| `api.tf` | archive_file zip, IAM role (least privilege), log group, Lambda arm64, HTTP API, throttled stage |
| `data.tf` | DynamoDB table (PITR, deletion protection) |
| `alerts.tf` | SNS topic + email, Lambda errors alarm, monthly budget |

Terraform packages the Lambda code itself (no out-of-band code deploy), so
code and config always change together in a reviewed plan.

## Pipeline
`New-App` ► `New-AppAccount` ► (spec + build) ► `Plan-App` ► human yes ►
`Apply-App` ► `Publish-App`. State per app lives in `.local/apps/<name>.json`.

## Hooks
| Hook | Trigger | Effect |
|---|---|---|
| `shell-guardrails` | PreToolUse (shell) | `scripts/hooks/Test-ShellCommand.ps1`; exit 2 blocks |
| `task-complete-alert` | PostTaskExec | `scripts/hooks/Send-TaskAlert.ps1`; emails the crew |
| `app-config-check` | PostFileSave `app.config.json` | agent checks the config rules |

## Decisions
- **Account per app** over one shared account: isolation and clean teardown;
  costs a few minutes of account creation, so accounts are pre-created before demos.
- **Same-origin API through CloudFront** over a separate API URL: no CORS, no
  build-time config.
- **Saved-plan applies** over `apply` with prompts: what runs is what was reviewed.
- **Role-based local profiles** over IAM user keys: nothing long-lived to leak.
