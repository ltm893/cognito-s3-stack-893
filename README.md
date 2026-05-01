# cognito-s3-stack-893

A forkable AWS CDK base stack providing Cognito auth + S3 storage. Deploy it once, then deploy any number of standalone add-on apps that share the same auth and storage layer.

## Repo family

| Repo | Status | Description |
|------|--------|-------------|
| `cognito-s3-stack-893` | ✅ This repo | Forkable base: Cognito + S3 + IAM |
| `mileage-expense-tracker-893` | ✅ Complete | Mileage + expense tracker with OCR receipt scanning |
| `music-player-893` | 🔜 Coming soon | S3 music streaming app |

## What this deploys

```
CognitoS3BaseStack-{id}
├── Cognito User Pool        — invite-only auth, email sign-in
├── Cognito App Client       — for mobile apps
├── Cognito Identity Pool    — temporary AWS credentials
├── S3 {id}-public           — publicly readable bucket
├── S3 {id}-private          — authenticated users only
└── IAM authenticated role   — scoped S3 access for Identity Pool
```

All resource names are prefixed with your `id` — deploy multiple instances on the same AWS account without collision.

## How the add-on pattern works

```
1. Fork + deploy cognito-s3-stack-893
        ↓ writes base_outputs.json

2. Fork + deploy an add-on (e.g. mileage-expense-tracker-893)
        ↓ reads base_outputs.json via BASE_OUTPUTS_PATH
        ↓ deploys its own stack on top
        ↓ writes its own outputs (e.g. met_outputs.json)

3. Build the iOS app
        ↓ reads outputs JSON for config (zero hardcoded values)
```

## Prerequisites

- AWS CLI configured (`aws configure`)
- AWS CDK bootstrapped (`npx cdk bootstrap`)
- Node.js 20+

## Quick start

```bash
# 1. Fork + clone
git clone https://github.com/ltm893/cognito-s3-stack-893.git
cd cognito-s3-stack-893

# 2. Set up config
cp base/bin/config.example.ts base/bin/config.ts
# Edit config.ts — set a unique id, your region, and email
# Example:
#   id:        "johndoe"         ← must be globally unique (used in S3 bucket names)
#   awsRegion: "us-east-1"
#   fromEmail: "you@example.com" ← must be verified in AWS SES

# 3. Deploy
cd base
chmod +x scripts/deploy.sh
./scripts/deploy.sh
# → creates CognitoS3BaseStack-{id}
# → writes base_outputs.json at repo root
```

The deploy script shows a summary of exactly what will be created before asking for confirmation.

## Config reference

```ts
export const config = {
  id:           "your-id-here",   // lowercase, hyphens ok — drives all resource names
  awsRegion:    "us-east-1",
  userPoolName: "your-id-here-app-users",
  fromEmail:    "noreply@yourdomain.com",
};
```

## base_outputs.json

Written to the repo root by `deploy.sh`. Gitignored — never committed. Add-ons read this file via `BASE_OUTPUTS_PATH` env var.

```json
{
  "version": "1",
  "aws_region": "us-east-1",
  "auth": {
    "user_pool_id":        "us-east-1_XXXXXXXXX",
    "user_pool_client_id": "...",
    "user_pool_provider":  "...",
    "identity_pool_id":    "us-east-1:...",
    "auth_role_arn":       "arn:aws:iam::..."
  },
  "storage": {
    "public_bucket":  "{id}-public",
    "private_bucket": "{id}-private"
  }
}
```

## Creating users

This stack uses invite-only auth — users must be created manually:

```bash
# Create user
aws cognito-idp admin-create-user \
  --user-pool-id <user_pool_id> \
  --username user@example.com \
  --temporary-password 'TempPass1!' \
  --message-action SUPPRESS \
  --region us-east-1

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id <user_pool_id> \
  --username user@example.com \
  --password 'PermPass1!' \
  --permanent \
  --region us-east-1
```

## Structure

```
cognito-s3-stack-893/
├── base/
│   ├── bin/
│   │   ├── app.ts              ← CDK entry — stack name = CognitoS3BaseStack-{id}
│   │   ├── config.ts           ← your values (gitignored)
│   │   └── config.example.ts   ← template — commit this, not config.ts
│   ├── lib/base-stack.ts       ← CDK stack definition
│   └── scripts/
│       ├── deploy.sh           ← deploy + write base_outputs.json
│       └── check-stack.sh      ← verify deployed stack outputs
└── shared/
    └── types/base-outputs.ts   ← TypeScript type for base_outputs.json
```

## Estimated AWS costs

| Service | Free tier | Est. cost at low usage |
|---------|-----------|------------------------|
| Cognito | 50,000 MAUs free | $0 |
| S3 | 5GB free | ~$0.023/GB/month |
| Lambda | 1M calls/month free | $0 |
| API Gateway | 1M calls/month free | $0 |
| DynamoDB | 25GB + 200M req free | $0 |
| Textract | No free tier | $0.0015/page |

## Cleanup

```bash
# Destroy the stack (S3 buckets are retained by default — delete manually if needed)
cd base
npx cdk destroy CognitoS3BaseStack-{id}

# Delete retained S3 buckets
aws s3 rb s3://{id}-public --force
aws s3 rb s3://{id}-private --force
```
