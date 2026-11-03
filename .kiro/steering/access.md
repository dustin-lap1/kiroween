# Access: GitHub and AWS

## GitHub
- The GitHub CLI is authenticated as the repo owner: check with `gh auth status`.
- This repo is public (hackathon rule). Never commit secrets, account ids,
  emails, Terraform state, or `scripts/config.local.psd1`.
- Commit with clear messages; push to `main` only when the human asks.
  Do not force push.

## AWS: who can do what
| Identity | Where | Used for |
|---|---|---|
| Management profile (`ManagementProfile` in `config.local.psd1`) | Organization management account | Creating accounts, the project OU and SCP. Never deploy app resources here. |
| `OrganizationAccountAccessRole` | each app account | One-time bootstrap only (creating the deployer role). It is exempt from some root SCPs, so it is never used for Terraform. |
| `skeleton-deployer` role, local profile `kw-<name>` | each app account | Terraform and Publish. Bound by every SCP. |

- Local profiles assume roles (`role_arn` + `source_profile`); there are no
  long-lived keys in app accounts, and the project SCP denies creating them.
- Confirm where you are before any AWS change:
  `aws sts get-caller-identity --profile kw-<name>`.
- Always pass `--profile kw-<name> --region us-east-1` to AWS CLI calls for an
  app. Never rely on whatever `AWS_PROFILE` happens to be set.
- The app's account id, profile, state bucket, and outputs are in
  `.local/apps/<name>.json` (gitignored). Read them from there; do not guess.

## Organization layout
- Project accounts live in the OU `Kiroween-2026`. The project SCP
  `Kiroween2026Guardrails` is attached to that OU only, on top of the root SCPs
  (see `platform/org/kiroween-guardrails.scp.json`).
- Setup is `.\scripts\Setup-Org.ps1` (idempotent; the human runs it once).
