# Terraform guardrails and safety checks

Terraform here creates real resources in real AWS accounts. Treat every apply
as risky until the plan proves otherwise.

## The only way to change infrastructure
1. `.\scripts\Plan-App.ps1 -Name <app>` (add `-Target <address>` for a small
   change to an existing app). It writes the backend config, runs init and
   `plan -out=tfplan`, and prints an impact summary with a risk level.
2. **Present the impact summary to the human** exactly as printed (CREATE,
   MODIFY, DESTROY, REPLACE, RISK LEVEL, ROLLBACK) and **wait for an explicit
   "yes"**. Any hesitation = stop.
3. `.\scripts\Apply-App.ps1 -Name <app>` applies that saved plan file, nothing
   else. It refuses plans older than 60 minutes and any plan that deletes or
   replaces resources.
4. Verify the result (outputs, site, `/api/health`) and report.

The first apply of a new app into its empty account is a full-stack plan; that
is expected. After that, prefer `-Target` for small changes.

## Never (the PreToolUse hook enforces these)
- `terraform apply` or `terraform destroy` directly
- `-auto-approve`
- `terraform state rm|mv|push`, `import`, `taint`, `force-unlock`
- `Apply-App.ps1 -AllowDestroy` (a human runs it, after reading the deletes)
- destructive AWS CLI calls (`s3 rb`, recursive `s3 rm`, `dynamodb delete-table`,
  closing or detaching accounts, deleting SCPs or OUs)
If a task seems to need one of these, stop and explain what and why.

## Built-in safety checks
- `allowed_account_ids = [var.account_id]` in the provider: Terraform refuses to
  run against any other account, even with the wrong profile.
- Partial S3 backend: state per app account, versioned, private, locked with
  DynamoDB. The project SCP denies deleting state buckets, purging state
  versions, and deleting the lock table.
- DynamoDB `deletion_protection_enabled = true`.
- The deployer role is bound by the Organization's SCPs (region lock, approved
  services only) and the project SCP.

## Reading a plan
- Read every resource change, including "forces replacement". A replacement of
  the DynamoDB table, the S3 bucket, or the CloudFront distribution is HIGH
  risk: say so and propose a non-replacing alternative.
- A Lambda code change shows as an in-place update of
  `aws_lambda_function.api` (`source_code_hash`). That is expected here:
  Terraform packages the code itself (archive_file), so there is no
  out-of-band code to clobber.
- Changing `app.config.json` collections updates the Lambda's `COLLECTIONS`
  environment variable (in-place update).

## Conventions
- `terraform fmt` before committing `.tf` files.
- Never hardcode account ids, profiles, or emails in `.tf` files; they come
  from the generated `local.auto.tfvars`.
- No secrets in variables or state. Reference Secrets Manager by name.
- Remove resources by deleting them from config, planning, and asking the
  human; never with state commands.
