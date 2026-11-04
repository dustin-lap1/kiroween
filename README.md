# 💀 Skeleton Crew: a serverless app skeleton for Kiro

**Kiroween 2026 · Category: Skeleton Crew**

One lean skeleton for AWS serverless web apps, one standard procedure, and a
Kiro setup (steering, hooks, specs) that makes every app come out the same way:
in its own AWS account, behind guardrails, reviewed before it touches the cloud.
The proof is two different apps in `apps/`, built from the same foundation with
the same pipeline.

## The problem
Starting a cloud app means re-deciding the same things every time: which
account, which architecture, how to deploy, how not to destroy production. An
AI agent makes the code fast but does not make those decisions safe by
itself. Skeleton Crew writes the decisions down once (as code, steering, and
hooks) so that the agent and the human follow them on every app.

## What every app gets

```mermaid
flowchart LR
  B[Browser] --> CF[CloudFront]
  CF -->|static| S3[(S3, private, OAC)]
  CF -->|/api/*| GW[API Gateway HTTP API]
  GW --> L[Lambda Node.js 22 arm64]
  L --> DB[(DynamoDB single table)]
  L -. errors alarm .-> SNS[SNS] --> E[Email]
  BUD[Monthly budget] --> E
```

- **Its own AWS account** in the `Kiroween-2026` OU, with a project-only SCP
  (us-east-1 only, no IAM users or keys, protected deployer role and Terraform state)
- **React 19 + Vite + Tailwind CSS 4** frontend with switchable spooky themes
- **A config-driven API**: declare collections and fields in `app.config.json`;
  the Lambda serves validated CRUD for them and the UI renders forms for them
- **Terraform** with a per-account S3 backend, `allowed_account_ids`, DynamoDB
  deletion protection, least-privilege IAM, and security headers
- **Operations from day one**: API error alarm and a cost budget by email

## The pipeline (identical for every app)

```powershell
.\scripts\New-App.ps1     -Name ghost-guestbook -Description "Leave a message for the spirits." -Theme ghost
# write the app's spec in Kiro (requirements, design, tasks) and run the tasks
.\scripts\Plan-App.ps1    -Name ghost-guestbook    # impact summary with a risk level
.\scripts\Apply-App.ps1   -Name ghost-guestbook    # after an explicit "yes": applies exactly that plan
.\scripts\Publish-App.ps1 -Name ghost-guestbook    # build, upload, invalidate, smoke test
```

| Step | What happens |
|---|---|
| `New-App` | copies `skeleton/` to `apps/<name>`, fills in name, description, theme; vends the AWS account (`New-AppAccount`) |
| Spec | `.kiro/specs/<name>/`: requirements, design, tasks; Kiro builds in `apps/<name>` only |
| `Plan-App` | writes backend config, `terraform plan -out=tfplan`, prints CREATE / MODIFY / DESTROY / REPLACE and a risk level |
| `Apply-App` | applies the saved plan only; refuses stale plans and any delete or replace without a human's `-AllowDestroy` |
| `Publish-App` | builds, uploads with cache headers, invalidates CloudFront, checks the site and `/api/health` |

## Kickoff prompt (build an app in a Kiro chat)
Open a Kiro window with only this repo, start a new **Vibe** session, and paste:

```text
Let's build a new app from the Skeleton Crew skeleton, as a conversation.
Follow the new-app procedure in .kiro/steering/new-app.md and every steering
rule in this repo. Work in checkpoints: do one checkpoint, report back in a few
lines, and end with a question. Do not start the next checkpoint until I answer.

1. Idea: ask me what the app is. Then propose the name (kebab-case), display
   name, one-line description, theme (pumpkin, ghost, slime, or blood), and the
   collections and fields for app.config.json. Wait for my OK or changes.
2. Scaffold: run .\scripts\New-App.ps1 with the agreed values. Report the
   account and the app folder.
3. Spec: write .kiro/specs/<name>/requirements.md (EARS), design.md, and
   tasks.md. Summarize them and ask me to approve or change them.
4. Build: do the tasks, changing only apps/<name>/ and the spec. Run
   npm run build in the app folder. Report what changed.
5. Plan: run .\scripts\Plan-App.ps1 -Name <name> and show me the impact
   summary exactly as printed. Wait for my explicit "yes".
6. Apply: only after my "yes", run .\scripts\Apply-App.ps1 -Name <name>.
7. Publish: run .\scripts\Publish-App.ps1 -Name <name>. Check /api/health,
   create one item and list it through <site_url>/api, then give me the URL.
8. Ask whether to commit and push. Do nothing with git until I say so.

Never run terraform, destructive AWS commands, or Apply-App -AllowDestroy
yourself. If anything fails, stop, explain it, and suggest the fix.
```

Sample answers when Kiro asks what the app is:

- **App one:** A guestbook where visitors leave a message for the spirits:
  their name, the message, and a mood (eerie, friendly, restless). Newest
  first, and each message shows a ghost emoji that matches its mood. Call it
  ghost-guestbook, ghost theme.
- **App two:** A trick-or-treat candy tracker with two collections: candy
  (name, kind: chocolate, gummy, sour, or hard, quantity as a number, nut free
  yes or no) and visitors (costume, group size as a number). Show total pieces
  of candy and total visitors at the top. Call it candy-stash, pumpkin theme.
- **App three:** A witch's potion shelf with one collection: potions (name,
  color: green, purple, or black, effect as a longer description, brewing time
  in minutes as a number, safe to drink yes or no, and a recipe link as a URL).
  Newest first, with color filter buttons above the list. Call it potion-shelf,
  slime theme.

## How Kiro is used

### Steering (`.kiro/steering/`)
**What it is:** steering files are Markdown files that give Kiro persistent
knowledge about a project: its purpose, conventions, and rules. Kiro reads them
so you don't have to repeat that context in every chat. Each file's front matter
sets when it is loaded: `always` (the default, every interaction), `fileMatch`
(when a file matching a pattern is in context), `auto` (when the request matches
the file's description), or `manual` (when you reference it with `#` in chat).

**How we use it:** the always-included files carry the rules every app must
follow; the others load only for the task or files they cover.

| File | Inclusion | What it teaches Kiro |
|---|---|---|
| `product.md`, `tech.md`, `structure.md` | always | what this is, the stack, where code goes |
| `aws-architecture.md` | always | serverless-only architecture, least privilege, validation, cost |
| `terraform-guardrails.md` | always | plan, present, explicit yes, saved-plan apply; what never to run |
| `deployment.md` | always | which command ships which change, what "deployed" means |
| `access.md` | always | GitHub and AWS identities, profiles, the OU |
| `aws-accounts.md` | auto | vending an account per app |
| `new-app.md` | auto | the standard new-app procedure |
| `app-config.md` | file match `app.config.json` | the config rules |
| `frontend.md` | file match `src/**` | styling tokens, accessibility, states |

### Hooks (`.kiro/hooks/`)
**What it is:** agent hooks are automations that run when an event happens in
the IDE or the agent's work, such as a file being saved, a tool about to run, or
a spec task completing. A hook either runs a shell command or adds a prompt to
the agent's context. A `PreToolUse` command hook that exits with code 2 blocks
the tool call, and its stderr is returned to Kiro as the reason.

**How we use it:** to enforce the Terraform guardrails without relying on the
agent remembering them, and to keep the crew informed as work finishes.

| Hook | Trigger | Effect |
|---|---|---|
| Infrastructure guardrails | PreToolUse, shell tools | blocks `terraform apply/destroy`, `-auto-approve`, state surgery, `-AllowDestroy`, and destructive AWS CLI calls (exit 2, with the reason sent back to Kiro) |
| Email the crew | PostTaskExec | each completed spec task emails the crew through SNS |
| App config changed | PostFileSave `app.config.json` | Kiro checks the config and reminds you how the change ships |

The pipeline scripts also email the crew when an app is scaffolded, applied, and published.

### Specs (`.kiro/specs/`)
**What it is:** a spec is Kiro's structured way to build a feature. It is a
folder of three Markdown documents written with Kiro in order:
`requirements.md` (user stories with acceptance criteria in EARS notation),
`design.md` (the technical design: architecture, components, data models, error
handling, testing), and `tasks.md` (a checklist of discrete implementation
tasks). You review each document before moving on, then Kiro runs the tasks one
at a time and tracks their status.

**How we use it:**
- `skeleton-foundation/`: the skeleton's own requirements, design, and tasks
- one spec per app, written with the `new-app` procedure

### Other Kiro capabilities (not used here)
The skeleton doesn't use these, but they are defined here for completeness.

- **Agent Skills** (`.kiro/skills/`, or `~/.kiro/skills/` globally): portable
  instruction packages that follow the open Agent Skills standard. A skill is a
  folder with a `SKILL.md` and optional scripts and templates. Kiro loads only
  each skill's name and description at startup, then loads the full skill when
  a request matches it or when you invoke it as a `/` slash command.
- **MCP servers** (`.kiro/settings/mcp.json`): Model Context Protocol servers
  give Kiro extra tools and data sources, such as documentation search or a
  service's API.
- **Powers**: installable bundles that package MCP servers, steering, and
  hooks for a specific tool or framework, activated when your work calls for
  them.
- **Custom agents**: agent configurations with their own prompt, tools,
  permissions, and resources (steering files, skills) for a recurring kind of
  task.
- **Autopilot and supervised modes**: in autopilot, Kiro works through a task
  on its own and you can review or revert afterwards; in supervised mode, it
  pauses after each turn with file edits so you can accept or reject each
  change.

## Repository layout
```
skeleton/        the template (app.config.json, src/, api/, infra/)
apps/            the apps built from it, one folder each
scripts/         the pipeline (Windows PowerShell 5.1)
platform/org/    the project SCP
.kiro/           steering, hooks, specs
docs/            WALKTHROUGH.md: the 20-minute live build
```

## Set up your own copy
Prerequisites: an AWS Organization (management account access), AWS CLI v2,
Terraform 1.7+, Node.js 22+, Git, GitHub CLI, Windows PowerShell 5.1+, Kiro.

```powershell
Copy-Item scripts\config.example.psd1 scripts\config.local.psd1   # fill it in
.\scripts\Setup-Org.ps1                    # OU Kiroween-2026 + project SCP (attached to that OU only)
.\scripts\New-AppAccount.ps1 -Name crew    # small account for the alert topic
.\scripts\Setup-CrewAlerts.ps1             # confirm the email AWS sends you
.\scripts\Setup-CrewAlerts.ps1 -Test
```
Then follow the pipeline above, or the full script in [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md).

Accounts in the OU still inherit any SCPs on your Organization root; the project
SCP only adds to them and touches nothing outside the OU.

## Cost
Everything is pay-per-request. An idle app costs close to nothing; the budget
alert (default $10 a month per app) emails you before it is a surprise.

## License
[MIT](LICENSE)
