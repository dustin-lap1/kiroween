# Requirements: Skeleton foundation

## Introduction
A reusable skeleton for AWS serverless web apps plus a standard pipeline, so
that two (or more) distinct apps can be built from the same foundation with
the same procedure, each in its own AWS account.

## Requirement 1: One-command scaffold
**User story:** As a builder, I want to create a new app from the skeleton with
one command, so that every app starts from the same foundation.
1. WHEN the builder runs `New-App.ps1 -Name <name> -Description <text>` THEN the
   system SHALL copy `skeleton/` to `apps/<name>/` without `node_modules`,
   `dist`, or Terraform working files.
2. WHEN the app is created THEN the system SHALL fill in the name, display
   name, description, and theme in `app.config.json`, `index.html`,
   `package.json`, and `README.md`, escaping JSON and HTML.
3. IF `apps/<name>` already exists THEN the system SHALL stop without changing it.
4. IF the name is not 3 to 21 lowercase letters, digits, or dashes starting
   with a letter THEN the system SHALL reject it.

## Requirement 2: An AWS account per app, inside a guarded OU
**User story:** As an Organization owner, I want each app in its own account
inside a project OU, so that blast radius and cost stay per app and project
guardrails do not affect the rest of my Organization.
1. WHEN an app account is vended THEN the system SHALL create (or reuse) a
   member account and move it into the `Kiroween-2026` OU.
2. The project SCP SHALL be attached to the project OU only.
3. The system SHALL create a `skeleton-deployer` role and a local profile that
   assumes it; it SHALL NOT create IAM users or access keys.
4. The system SHALL create a versioned, private Terraform state bucket and a
   lock table in the app account.
5. Re-running the vending script SHALL be safe (idempotent).

## Requirement 3: Configurable, validated API
**User story:** As a builder, I want to define my app's data in a config file,
so that the API and UI adapt without new backend code.
1. The API SHALL serve list, create, read, update, and delete for every
   collection in `app.config.json` under `/api/<collection>`.
2. WHEN a request has unknown fields, wrong types, missing required fields,
   over-length strings, or a body over 8 KB THEN the API SHALL reject it with
   400 or 413 and SHALL NOT store anything.
3. `GET /api/health` SHALL return `ok: true` and the app name.
4. The API SHALL NOT log request bodies.

## Requirement 4: Themed, config-driven UI
1. The UI SHALL render one panel per collection with a form built from its fields.
2. The theme SHALL come from `app.config.json` and use semantic color tokens only.
3. The UI SHALL show loading, empty, and error states and work at 360 px wide.

## Requirement 5: Safe infrastructure changes
**User story:** As an operator, I want every infrastructure change reviewed
before it runs, so that the agent cannot destroy or replace resources unnoticed.
1. `Plan-App.ps1` SHALL save a plan and print CREATE, MODIFY, DESTROY, REPLACE,
   and a risk level.
2. `Apply-App.ps1` SHALL apply only the saved plan, SHALL refuse plans older
   than 60 minutes, and SHALL refuse deletes or replaces without `-AllowDestroy`.
3. Terraform SHALL refuse to run against any account but the app's own.
4. A PreToolUse hook SHALL block the agent from running `terraform apply`,
   `terraform destroy`, `-auto-approve`, state surgery, `-AllowDestroy`, and
   destructive AWS CLI commands.

## Requirement 6: Publish and notify
1. `Publish-App.ps1` SHALL build, upload with correct cache headers, invalidate
   CloudFront, and smoke-test the site and `/api/health`.
2. WHEN a spec task completes, a scaffold finishes, an apply succeeds, or a
   publish finishes THEN the system SHALL email the crew through SNS.
3. Every app SHALL have an API error alarm and a monthly cost budget that email
   the configured address.
