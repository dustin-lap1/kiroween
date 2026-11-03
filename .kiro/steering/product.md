# Product: Skeleton Crew (Kiroween 2026)

## What this is
A skeleton template for **AWS serverless web apps**, entered in the Kiroween
2026 hackathon (category **Skeleton Crew**). One foundation, one standard
procedure, and every new app gets the same production basics: its own AWS
account inside a guarded OU, a React frontend on CloudFront, a validated API
on Lambda, DynamoDB, alarms, a budget, and Terraform with safety checks.

The proof is two distinct apps built from the same skeleton with the same
pipeline, each in its own folder under `apps/`.

## Who it is for
Builders who want to go from idea to a live, well-architected AWS app in
minutes without re-deciding the account setup, the architecture, or the
guardrails each time. Teams that want Kiro to follow the same rules on every
app (steering) and to stop risky commands on its own (hooks).

## How an app is made (the pipeline)
1. `New-App.ps1`: copy the skeleton, name and theme it, vend its AWS account.
2. Write a spec for the app (requirements, design, tasks) and let Kiro build it.
3. `Plan-App.ps1`: Terraform plan with an impact summary.
4. Human says "yes". `Apply-App.ps1` applies exactly that plan.
5. `Publish-App.ps1`: build, upload, invalidate, smoke test.
Hooks email the crew as tasks finish and block unsafe infrastructure commands.

## Hackathon requirements this repo must keep meeting
- Public GitHub repo with an OSI license (MIT, `LICENSE`).
- `/.kiro` (specs, hooks, steering) committed at the root. Never gitignore it.
- Two separate app folders: `apps/<app-one>/` and `apps/<app-two>/`.
- Submission by December 4, 2026, 2:00 PM PT; demo video under 3 minutes.

## Conventions
- The skeleton stays lean: add a capability to `skeleton/` only when both apps
  (or any app) benefit. App-specific code lives in that app's folder.
- Halloween flavor is welcome in copy and themes; the engineering is not a joke.
