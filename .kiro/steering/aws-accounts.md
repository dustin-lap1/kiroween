---
inclusion: auto
name: aws-accounts
description: How to create (vend) a new AWS account for an app in the Organization, move it into the Kiroween-2026 OU, and set up the deployer role, local profile, and Terraform state. Use when creating an app account or fixing account access.
---

# Creating AWS accounts for apps

Every app gets its **own AWS account**. Blast radius, cost, and cleanup stay
per app.

## The command
```powershell
.\scripts\New-AppAccount.ps1 -Name <app-name>       # New-App.ps1 calls this for you
```
It is idempotent: re-run it safely after any failure.

## What it does
1. Uses the management profile to create the member account (email from
   `AccountEmailTemplate`, name `Kiroween <app-name>`), or reuses an active
   account with the same email, or `-AccountId <id>`. Takes 1 to 4 minutes.
2. Moves the account into the OU `Kiroween-2026`, where the project SCP applies.
3. Assumes `OrganizationAccountAccessRole` once to create the role
   `skeleton-deployer` (AdministratorAccess inside the account, trusted only
   by the management principal, bound by all SCPs).
4. Adds the local profile `kw-<app-name>` (`role_arn` + `source_profile`) and
   verifies it reaches the right account.
5. Creates the Terraform state bucket `<app-name>-tfstate-<account-id>`
   (versioned, private) and the lock table `terraform-locks`.
6. Saves it all to `.local/apps/<app-name>.json`.

## Rules
- Account creation is slow and hard to undo (closing an account takes 90 days
  to finalize). Create accounts only when the human asked for the app, and
  pre-create them before a live demo.
- Do not create accounts in a loop or to "retry" a failed app; re-run the script.
- Never close, remove, or move accounts out of the OU; tell the human instead.
- If `create-account` fails with a quota error, stop and report it (the
  Organization has an account limit).
- App names: 3 to 21 chars, lowercase letters, digits, dashes, starting with a
  letter (they become bucket and resource names).

## Prerequisites (one time)
- `scripts/config.local.psd1` (copy of `config.example.psd1`)
- `.\scripts\Setup-Org.ps1` has run (creates the OU and SCP, writes `.local/org.json`)
- Optional: `.\scripts\New-AppAccount.ps1 -Name crew` then
  `.\scripts\Setup-CrewAlerts.ps1` for email alerts
