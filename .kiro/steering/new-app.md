---
inclusion: auto
name: new-app
description: The standard procedure for creating a new serverless web app from the skeleton (scaffold, spec, plan, apply, publish). Use when the user wants to start, build, or deploy a new app in this repo.
---

# New app procedure

Follow these steps in order for every app. The point of the skeleton is that
the procedure never changes; only the app's spec does.

## 1. Scaffold (about 1 minute if the account exists)
```powershell
.\scripts\New-App.ps1 -Name <name> -DisplayName "<Display Name>" -Description "<one line>" -Theme <pumpkin|ghost|slime|blood>
```
Creates `apps/<name>/` from `skeleton/`, fills in `app.config.json`, ensures the
app's AWS account, runs `npm install`, and marks it the active app.

## 2. Spec (Kiro spec mode)
Create `.kiro/specs/<name>/` with requirements, design, and tasks.
- **Requirements:** user stories with EARS acceptance criteria.
- **Design:** state which skeleton parts are reused as-is, the collections and
  fields in `app.config.json`, any new endpoint or access pattern (key shape or
  GSI), UI changes, and theme. Keep the skeleton architecture
  (`aws-architecture.md`).
- **Tasks:** small, ordered, each one verifiable. Typical order:
  1. Define collections in `apps/<name>/app.config.json`
  2. API changes in `apps/<name>/api/` (pure logic in `api/lib/`)
  3. UI in `apps/<name>/src/`
  4. Infra changes in `apps/<name>/infra/` (only if needed)
  5. Plan and apply (stop for the human's yes)
  6. Publish and verify
Only touch `apps/<name>/`. Do not edit `skeleton/` from an app spec.

## 3. Build
Run the tasks. Build the frontend (`npm run build` in the app folder) after UI
tasks to catch errors early. The task-complete hook emails the crew after each task.

## 4. Plan, approve, apply
```powershell
.\scripts\Plan-App.ps1 -Name <name>
```
Show the impact summary. Wait for "yes". Then:
```powershell
.\scripts\Apply-App.ps1 -Name <name>
```
A first apply takes 3 to 6 minutes (CloudFront).

## 5. Publish and verify
```powershell
.\scripts\Publish-App.ps1 -Name <name>
```
Report the site URL and that `/api/health` is OK.

## Done means
- `apps/<name>/` builds, the site URL serves the app, `/api/health` is OK, and a
  create + list through the UI works.
- The spec's tasks are checked off.
