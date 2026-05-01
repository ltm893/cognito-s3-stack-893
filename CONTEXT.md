# CONTEXT.md — cognito-s3-stack-893
# Read this first at the start of every session.

## What this repo is
A forkable AWS CDK base stack providing Cognito auth + S3 storage.
Deploy it once, then deploy standalone add-on apps that consume its outputs.

## Repo family
| Repo | Status | Description |
|------|--------|-------------|
| `cognito-s3-stack-893` | ✅ Deployed | Forkable base: Cognito + S3 + IAM |
| `mileage-expense-tracker-893` | ✅ Created, backend ready | Mileage + expense tracker with OCR |
| `music-player-893` | ❌ Not created yet | S3 music streaming app |

## Architecture decisions
- Add-on repos are **standalone** — not nested inside this repo
- Add-ons read `base_outputs.json` via `BASE_OUTPUTS_PATH` env var
- No shared npm packages — `base-outputs.ts` type is copied into each add-on
- No Amplify SDK — iOS apps use raw URLSession + Cognito SRP

## This repo's current state
- `base/` — CDK stack (Cognito User Pool, Identity Pool, S3 buckets, IAM)
- `shared/types/base-outputs.ts` — TypeScript type + loader for base_outputs.json
- `base_outputs.json` — written by deploy.sh (gitignored, contains real AWS IDs)
- `apps/` — **TO BE REMOVED** (mileage-tracker has been migrated to its own repo)

## Cleanup needed (next session)
- Delete `apps/mileage-tracker/` — migrated to `mileage-expense-tracker-893`
- Delete `apps/music-player/` — will become `music-player-893`
- Delete `apps/` directory entirely
- Update README.md to reflect clean base-only structure

## base_outputs.json (deployed values)
- Region: us-east-1
- User Pool: us-east-1_5Ys317ypI
- Identity Pool: us-east-1:c9516012-77b7-4106-8fe6-d13046546d40
- Public bucket: test893-public
- Private bucket: test893-private

## Next session — start here
1. Read this file
2. Read `/Users/ltm893/Dev/projects/mileage-expense-tracker-893/CONTEXT.md`
3. Clean up `apps/` from this repo
4. Start `music-player-893` standalone repo
5. Then: iOS app for mileage-expense-tracker-893
