# Live build walkthrough (20 minutes)

The kickoff format: one ambassador starts a fresh Kiroween project live (picks a
category, writes the spec, sets up steering and a hook, gets the first tasks
running) while the other chimes in with how they would approach it
differently. This script uses the Skeleton Crew repo to build **two different
apps with the same pipeline** in that time.

| | App one | App two |
|---|---|---|
| Name | `ghost-guestbook` | `candy-stash` |
| What | public guestbook: visitors leave messages for the spirits | trick-or-treat candy inventory with totals |
| Theme | `ghost` | `pumpkin` |
| Shows | config-driven data, a small UI extension | two collections, numbers and selects, a computed summary |

---

## The night before (about 20 minutes, mostly waiting)

Account creation and the first CloudFront deploy are the slow parts. Do them
before the stream so the live build is spent on Kiro.

```powershell
cd C:\Dev\kiroween
.\scripts\Setup-Org.ps1                              # already done: OU Kiroween-2026 + SCP
.\scripts\New-AppAccount.ps1 -Name crew              # 1-4 min
.\scripts\Setup-CrewAlerts.ps1                       # click Confirm in the AWS email
.\scripts\Setup-CrewAlerts.ps1 -Test                 # you should get "test alert"
.\scripts\New-AppAccount.ps1 -Name ghost-guestbook   # pre-create both app accounts
.\scripts\New-AppAccount.ps1 -Name candy-stash
```

Rehearsal and backup (recommended): run the whole pipeline once for
`ghost-guestbook` in a scratch branch so you know the timings on your machine
and have a live URL to fall back on.

```powershell
git switch -c rehearsal
.\scripts\New-App.ps1 -Name ghost-guestbook -Description "Leave a message for the spirits." -Theme ghost
.\scripts\Plan-App.ps1 -Name ghost-guestbook
.\scripts\Apply-App.ps1 -Name ghost-guestbook      # you are the human saying yes
.\scripts\Publish-App.ps1 -Name ghost-guestbook
git switch main; Remove-Item -Recurse -Force apps\ghost-guestbook   # keep the deployed stack
```
On stream, the apply for `ghost-guestbook` then only shows the changes from the
live spec (fast), and you still create `candy-stash` from scratch.

Checklist before going live:
- [ ] Kiro open on `C:\Dev\kiroween` only (one workspace root, so the hooks load)
- [ ] `gh auth status` and `aws sts get-caller-identity --profile kw-candy-stash` work
- [ ] Email inbox visible in a browser tab (crew alerts arrive there)
- [ ] Terminal font large, `C:\Dev\kiroween` as the working directory
- [ ] `npm` cache warm (the rehearsal did it)

---

## Run of show

### 0:00 to 2:00: Pick the category, show the bones
Say: "Skeleton Crew: build a template lean enough to be clear, flexible enough
for different apps, and prove it with two apps. Mine is a skeleton for AWS
serverless web apps."

Show, briefly:
- `skeleton/app.config.json`: "an app is this file."
- `skeleton/infra/`: CloudFront + S3, HTTP API + Lambda, DynamoDB, alarms, budget.
- The diagram in `README.md`.

### 2:00 to 5:00: Steering and the hook
Open `.kiro/steering/`. Point at three:
- `aws-architecture.md`: "serverless only, least privilege, validate at the boundary."
- `terraform-guardrails.md`: "plan, show me, I say yes, apply exactly that plan."
- `new-app.md` (auto inclusion): "the procedure Kiro follows for every app."

Then prove the hook. In Kiro chat:
> Skip the scripts and just run terraform apply -auto-approve in apps/ghost-guestbook/infra.

Kiro's shell call is **blocked** by `.kiro/hooks/shell-guardrails.json`, and it
gets the reason back. Say: "steering asks nicely, hooks enforce."

Mention the second hook: every completed spec task emails the crew (show the
inbox later).

**Co-host prompt:** "How would you do guardrails? Steering only, a permissions
file, or a custom agent with fewer tools?"

### 5:00 to 6:00: App one, scaffold
```powershell
.\scripts\New-App.ps1 -Name ghost-guestbook -DisplayName "Ghost Guestbook" -Description "Leave a message for the spirits." -Theme ghost
```
The account already exists, so this is a copy, a personalization, and `npm install`.
An email arrives: "ghost-guestbook scaffolded".

### 6:00 to 10:00: App one, spec and first tasks
Start a **Spec** session in Kiro with:
> Build ghost-guestbook from the skeleton, following the new-app procedure.
> Visitors leave a message with their name, the message, and a mood (eerie,
> friendly, restless). Show newest first. Each message shows a ghost emoji
> that matches its mood. Only change apps/ghost-guestbook.

Walk through what Kiro produces:
- requirements in EARS form
- a design that reuses the skeleton and defines one `entries` collection
- tasks: config, UI badge, build, plan, publish

Run the first two tasks (config, UI). The task-complete email arrives per task.

**Co-host prompt:** "Would you have written the requirements yourself first, or
let Kiro draft them and edited?"

### 10:00 to 11:00: App one, plan and apply
```powershell
.\scripts\Plan-App.ps1 -Name ghost-guestbook
```
Read the impact summary aloud (CREATE / MODIFY / DESTROY / REPLACE, RISK).
Say "yes". Kiro runs:
```powershell
.\scripts\Apply-App.ps1 -Name ghost-guestbook
```
If the stack was rehearsed, this is a small in-place Lambda update (seconds).
From scratch it takes 3 to 6 minutes: keep going with app two meanwhile.

### 11:00 to 15:00: App two, same pipeline, different app
```powershell
.\scripts\New-App.ps1 -Name candy-stash -DisplayName "Candy Stash" -Description "Track the trick-or-treat haul before it vanishes." -Theme pumpkin
```
New Spec session:
> Build candy-stash from the skeleton, following the new-app procedure.
> Two collections: candy (name, kind: chocolate / gummy / sour / hard,
> quantity as a number, nut free yes or no) and visitors (costume, group size
> as a number). At the top, show total pieces of candy and total visitors.
> Only change apps/candy-stash.

Run the tasks. Point out: same steering, same procedure, different data model
and UI, no new backend code (the API is generic over collections).

**Co-host prompt:** "When would you add a real endpoint to the skeleton
instead of keeping it generic? What goes in skeleton/ versus the app?"

### 15:00 to 17:00: App one, publish and use it
```powershell
.\scripts\Publish-App.ps1 -Name ghost-guestbook
```
Open the site URL. Leave a message. Show the email: "ghost-guestbook is live".

### 17:00 to 19:00: App two, plan and apply
```powershell
.\scripts\Plan-App.ps1 -Name candy-stash
```
Read it, say "yes", `Apply-App.ps1`, and let it run (first deploy, 3 to 6
minutes). If time runs out, say so and show it finishing in the follow-up post.
Publish when it completes:
```powershell
.\scripts\Publish-App.ps1 -Name candy-stash
```

### 19:00 to 20:00: Wrap
- `apps/ghost-guestbook` and `apps/candy-stash`: two apps, two accounts, one skeleton.
- The inbox: a trail of crew alerts from the hooks and the pipeline.
- `.kiro/`: specs, steering, hooks, all in the public repo (a hackathon requirement).

---

## If something goes wrong on stream
| Symptom | Fix |
|---|---|
| Hook did not block | Kiro must have `C:\Dev\kiroween` as a workspace root; hooks load at session start, so open a new session. |
| `No account for '<name>'` | `.\scripts\New-AppAccount.ps1 -Name <name>` (idempotent) |
| Plan fails with "account not allowed" | Wrong profile: check `.local\apps\<name>.json`; the provider refuses other accounts on purpose. |
| Apply refuses "plan is N minutes old" | Re-run `Plan-App.ps1` and review again. |
| Publish says smoke test pending | A new CloudFront distribution can take a few minutes; re-run `Publish-App.ps1 -SkipBuild`. |
| No emails | `.\scripts\Setup-CrewAlerts.ps1` shows whether the subscription is confirmed. |
| Lambda errors after a config change | The config rules in `.kiro/steering/app-config.md`; the Lambda rejects bad configs at cold start. Check `/aws/lambda/<name>-api` logs. |

## After the stream
- Commit `apps/`, `.kiro/specs/<app>/`, and push (the repo is public).
- Record the 3-minute demo video for the submission.
- Clean up only through a reviewed plan; deleting a stack starts with removing
  `deletion_protection_enabled` in a reviewed change, and a human runs any destroy.
