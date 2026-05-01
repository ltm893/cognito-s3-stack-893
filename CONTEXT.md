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
- Stack name derived from `config.id` — prevents same-account collisions when fork testing

## This repo's current state
- `base/` — CDK stack (Cognito User Pool, Identity Pool, S3 buckets, IAM)
- `base/bin/app.ts` — stack name = `CognitoS3BaseStack-{config.id}`
- `base/bin/config.example.ts` — template for forkers (config.ts is gitignored)
- `base/scripts/deploy.sh` — reads config.ts via grep, shows resource summary before confirm
- `shared/types/base-outputs.ts` — TypeScript type for base_outputs.json
- `base_outputs.json` — written by deploy.sh (gitignored, contains real AWS IDs)
- `apps/` — deleted (add-ons migrated to standalone repos)

## base_outputs.json (deployed values — test893)
- Region: us-east-1
- User Pool: us-east-1_5Ys317ypI
- Identity Pool: us-east-1:c9516012-77b7-4106-8fe6-d13046546d40
- Public bucket: test893-public
- Private bucket: test893-private

## Deploy script improvements made this session
- Stack name now derived from `config.id` (was hardcoded `CognitoS3BaseStack`)
- Config values read via `grep` not `node -e` (avoids ts-node compile issue)
- Pre-confirmation summary shows exactly what AWS resources will be created

## Fork test results
- Fork simulation in `~/Dev/projects/fork-test/`
- `cognito-s3-stack-fork` → deployed as `CognitoS3BaseStack-forktest2` ✅
- `mileage-expense-tracker-fork` → deployed as `MileageExpenseStack-forktest2` ✅
- All forktest2 resources are completely separate from test893 resources
- forktest2 User Pool: us-east-1_WcbV9X7iG
- forktest2 buckets: forktest2-public, forktest2-private, forktest2-met-receipts
- iOS Option B test in progress (open fork Xcode project, add met_outputs.json, build)

## Next session — start here
1. Read this file
2. Read `/Users/ltm893/Dev/projects/mileage-expense-tracker-893/CONTEXT.md`
3. Complete iOS Option B fork test if not done:
   - Create forktest2 Cognito user (commands below)
   - Open fork Xcode project, add met_outputs.json, build + run
4. Clean up fork-test stacks from AWS when done (destroy forktest2 stacks)
5. Start `music-player-893` standalone repo

## Useful commands

### Create forktest2 test user
```bash
aws cognito-idp admin-create-user \
  --user-pool-id us-east-1_WcbV9X7iG \
  --username testuser@forktest2.com \
  --temporary-password "Temp1234!" \
  --message-action SUPPRESS \
  --region us-east-1

aws cognito-idp admin-set-user-password \
  --user-pool-id us-east-1_WcbV9X7iG \
  --username testuser@forktest2.com \
  --password "Fork2test!" \
  --permanent \
  --region us-east-1
```

### Destroy forktest2 stacks when done
```bash
cd ~/Dev/projects/fork-test/mileage-expense-tracker-fork/backend
BASE_OUTPUTS_PATH=~/Dev/projects/fork-test/cognito-s3-stack-fork/base_outputs.json \
  npx cdk destroy MileageExpenseStack-forktest2

cd ~/Dev/projects/fork-test/cognito-s3-stack-fork/base
npx cdk destroy CognitoS3BaseStack-forktest2
```

### Deploy MET add-on (original)
```bash
cd ~/Dev/projects/mileage-expense-tracker-893/backend
BASE_OUTPUTS_PATH=~/Dev/projects/cognito-s3-stack-893/base_outputs.json \
  ./scripts/deploy.sh
```
