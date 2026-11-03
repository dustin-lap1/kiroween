# AWS architecture best practices

Every app in this repo follows the same architecture. Extend it; do not
replace it without a stated reason.

```
Browser ──► CloudFront ──► S3 (private, OAC)            static frontend
                 └── /api/* ──► API Gateway (HTTP API) ──► Lambda ──► DynamoDB
Alarms + budget ──► SNS ──► email
```

## Serverless only
- Allowed building blocks: Lambda, API Gateway, DynamoDB, S3, CloudFront,
  Cognito, EventBridge, SQS, SNS, SES, Bedrock, Secrets Manager, CloudWatch.
- EC2, RDS, ECS, EKS, ElastiCache, Kinesis, Glue, Athena, SageMaker and similar
  are blocked by the Organization's SCPs. Do not propose them; find the
  serverless equivalent (Lambda, DynamoDB, S3, SQS, EventBridge).
- us-east-1 only.

## Security (least privilege, private by default)
- S3 buckets: private, BucketOwnerEnforced, public access blocked, readable only
  by this app's CloudFront distribution (OAC + `AWS:SourceArn`).
- Lambda roles: only the actions and resources the function uses (table ARN,
  its own log group). No `*` actions, no `AdministratorAccess` on workloads.
- Validate every request at the API boundary (`api/lib/collections.mjs`):
  declared fields only, types, lengths, body size. Reject, never coerce silently.
- Never log request bodies, secrets, or tokens. Log error name and message.
- Secrets in Secrets Manager or SSM Parameter Store (SecureString), read at
  runtime. Never in code, Terraform variables, tfvars, or Lambda env vars.
- The API is public and unauthenticated by default, throttled at the stage
  (burst 50, rate 20). Add Cognito (JWT authorizer) when an app has users or
  private data.
- CloudFront responses carry the managed security headers policy.
- No IAM users or access keys anywhere (the project SCP denies them). Humans
  and pipelines use roles.

## Reliability and operations
- DynamoDB: on-demand, point-in-time recovery, deletion protection.
- Every Lambda has an explicit log group with retention (14 days) and an
  errors alarm to the app's SNS topic.
- Every account has a monthly budget with email alerts (80% actual, 100%
  forecast).

## Cost
- Pay-per-request everywhere; nothing runs idle. CloudFront `PriceClass_100`.
- A new app should cost cents a month at demo traffic.

## Data modeling (single table)
- `pk = C#<collection>`, `sk = <id>` for collection items, newest first.
- New access pattern = a new key shape or a GSI, designed in the app's spec
  before code. Never Scan in a request path.

## Tags
Provider `default_tags`: `App`, `ManagedBy = terraform`, `Project = kiroween-skeleton-crew`.
