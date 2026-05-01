# CONTEXT.md — cognito-s3-stack-893
# Read this first at the start of every session.

## What this repo is
A forkable AWS CDK base stack providing Cognito auth + S3 storage.
Deploy it once, then deploy standalone add-on apps that consume its outputs.

## Repo family
| Repo | Status | Description |
|------|--------|-------------|
| `cognito-s3-stack-893` | ✅ Deployed + public | Forkable base: Cognito + S3 + IAM |
| `mileage-expense-tracker-893` | ✅ Complete + public | Mileage + expense tracker with OCR |
| `music-player-893` | ❌ Not created yet | S3 music streaming app |

## Architecture decisions
- Add-on repos are **standalone** — not nested inside this repo
- Add-ons read `base_outputs.json` via `BASE_OUTPUTS_PATH` env var
- No shared npm packages — `base-outputs.ts` type is copied into each add-on
- No Amplify SDK — iOS apps use raw URLSession + Cognito SRP
- Stack name = `CognitoS3BaseStack-{id}` — prevents same-account collisions

## This repo's current state
- `base/bin/app.ts` — stack name derived from `config.id`
- `base/bin/config.example.ts` — template for forkers (config.ts is gitignored)
- `base/scripts/deploy.sh` — reads config via grep, shows resource summary before confirm
- `shared/types/base-outputs.ts` — TypeScript type for base_outputs.json
- `base_outputs.json` — gitignored, written by deploy.sh
- `apps/` — deleted (add-ons migrated to standalone repos)

## base_outputs.json (deployed values — test893)
- Region: us-east-1
- User Pool: us-east-1_5Ys317ypI
- Identity Pool: us-east-1:c9516012-77b7-4106-8fe6-d13046546d40
- Public bucket: test893-public
- Private bucket: test893-private

## Fork test — COMPLETE ✅
- Simulated in `~/Dev/projects/fork-test/`
- `CognitoS3BaseStack-forktest2` deployed with separate User Pool, buckets
- `MileageExpenseStack-forktest2` deployed with separate tables, API, bucket
- iOS app built pointing at forktest2 backend — login + expense creation confirmed
- forktest2 stacks destroyed after test, retained resources cleaned up manually

## Next session — start here
1. Read this file
2. Read `/Users/ltm893/Dev/projects/mileage-expense-tracker-893/CONTEXT.md`
3. Start `music-player-893` standalone repo

## Useful commands

### Deploy base stack
```bash
cd ~/Dev/projects/cognito-s3-stack-893/base
./scripts/deploy.sh
```

### Deploy MET add-on
```bash
cd ~/Dev/projects/mileage-expense-tracker-893/backend
BASE_OUTPUTS_PATH=~/Dev/projects/cognito-s3-stack-893/base_outputs.json \
  ./scripts/deploy.sh
```

### Create a Cognito user
```bash
aws cognito-idp admin-create-user \
  --user-pool-id <user_pool_id> \
  --username user@example.com \
  --temporary-password 'TempPass1!' \
  --message-action SUPPRESS \
  --region us-east-1

aws cognito-idp admin-set-user-password \
  --user-pool-id <user_pool_id> \
  --username user@example.com \
  --password 'PermPass1!' \
  --permanent \
  --region us-east-1
```

### Destroy a stack + retained resources
```bash
npx cdk destroy CognitoS3BaseStack-{id}
aws s3 rb s3://{id}-public --force
aws s3 rb s3://{id}-private --force
```
