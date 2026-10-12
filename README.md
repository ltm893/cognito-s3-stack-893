# cognito-s3-stack-893

A forkable AWS CDK base stack providing Cognito auth + S3 storage. Deploy it once, then deploy any number of standalone add-on apps that share the same auth and storage layer.

## Repo family

This is the map for the `apps-893` folder. Each directory is its own git repo. The repos share an AWS account through config files and outputs JSON.

### Roles

| Repo | Kind | Role |
|------|------|------|
| `cognito-s3-stack-893` | Base | Cognito and S3. Deploy this first. |
| `dropbox-893` | CDK add-on | Private files and public slideshow albums |
| `calendar-893` | CDK add-on | Calendar API |
| `pdf-search-893` | CDK add-on | Ancestry OCR search |
| `video-convert-893` | CDK add-on | DVD ingest, clip, and combine. Needs `dropbox-893`. Users open the MP4 from the Dropbox file list |
| `mileage-expense-tracker-893` | iOS + CDK | Mileage and expenses. Can share this user pool |
| `web-app-893` | Amplify frontend | Generic website template |
| `dliv-web` | Amplify frontend | Live fork of `web-app-893`. `dev` is https://dev.dliv.com and `main` is https://dliv.com |
| `music-player-893` | iOS | Plays files from the Dropbox API |

### Handoff

Each backend `deploy.sh` writes an outputs JSON with the pool id, client id, and API URL. Websites and iOS apps are pointed at those values.

`web-app-893` and `dliv-web` turn Amplify branch environment variables into `frontend/dliv_outputs.json` when that branch builds. `music-player-893` reads a local `dliv_outputs.json`. Mileage reads `met_outputs.json`.

### Branches

Each repo has its own `dev` and `main`. On `dliv-web`, Amplify serves `dev` at https://dev.dliv.com and `main` at https://dliv.com. Which API a page calls is the environment variable on that Amplify branch. A merge inside `dropbox-893` or `pdf-search-893` leaves the site and those variables as they are.

### Deploy

Amplify hosts `web-app-893` and `dliv-web` only. Backends deploy with `deploy.sh`. The sites use raw Cognito SRP.

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

2. Deploy add-ons (dropbox-893, calendar-893, and optionally pdf-search-893). video-convert-893 needs dropbox-893 first
        ↓ id comes from base/bin/config.ts when the add-on config omits it
        ↓ copy the user pool id and bucket names from base_outputs.json into that add-on's config.ts
        ↓ calendar table defaults to {id}-calendar and createTable defaults to true
        ↓ each writes its own outputs JSON

3. Point a website or iOS app at those outputs
        web-app-893 / dliv-web → Amplify env vars
        music-player / MilesExpenses → dliv_outputs.json / met_outputs.json
```

## Prerequisites

- An AWS administrator account, with access keys installed (`aws configure`)
- CDK bootstrapped once in that account and region (below)
- Node.js 20+

## Bootstrap CDK

Do this once for the AWS account and region before the first `deploy.sh` or `./scripts/new-site.sh` deploy. The region is `awsRegion` in `base/bin/config.ts`. Later add-ons in that same account and region reuse this bootstrap.

```bash
aws sts get-caller-identity
cd base
npm install
npx cdk bootstrap aws://ACCOUNT/REGION
```

`ACCOUNT` is the account number from `aws sts get-caller-identity`. For account `123456789012` in `us-east-1`:

```bash
npx cdk bootstrap aws://123456789012/us-east-1
```

CDK creates a stack named `CDKToolkit` in that region. That stack holds the bucket and roles used by later deploys. AWS guide: [Bootstrapping](https://docs.aws.amazon.com/cdk/v2/guide/bootstrapping.html).

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

## Start another site

```bash
./scripts/new-site.sh
```

The id you type is the folder `~/Dev/projects/<id>/` and the `id` in `base/bin/config.ts`. The user pool is `<id>-app-users`. The buckets are `<id>-public` and `<id>-private`. The script clones this repo’s `dev` branch into that folder. The git directory stays `cognito-s3-stack-893`. A deploy needs an AWS administrator account with keys installed (`aws configure`). The script stops that deploy when the keys are missing. Bootstrap that account and region once first. See [Bootstrap CDK](#bootstrap-cdk).

It asks whether to deploy the base stack. `base/scripts/deploy.sh` asks again and lists the resources before it creates them.

The menu then clones one add-on at a time: Dropbox, calendar, PDF search, or video convert. After that `config.ts` is written, it asks whether to deploy that stack. The pool id and bucket names are copied from `base_outputs.json`. Until that file exists, the add-on deploy is skipped. Video convert is refused until `dropbox-893` is in that folder. Finished MP4s open from the Dropbox file list. Its deploy also stops unless local Docker is running, because the Fargate image is built on this machine. PDF search does not need Dropbox. Choose **5** when you are done. Run the script again with the same id to add another add-on. `dliv-web` is not cloned.

`scripts/new-site.test.sh` answers those prompts against a temporary folder. It does not call AWS.

## Check or remove a site

```bash
./scripts/validate-site.sh
./scripts/destroy-site.sh
```

Both read `id` and `awsRegion` from `base/bin/config.ts`. Validate prints the stacks, buckets, tables, user pool, APIs, and the video-convert cluster for that id. It exits 1 when a stack is failed or rolling back.

Destroy deletes the add-on stacks first and the base stack last, then the retained buckets, tables, user pool, and leftover API, cluster, and log group. CloudFormation keeps those buckets, tables, and the user pool after the stack is gone, so the script removes them itself. Type the site id to confirm. `CDKToolkit` and any Amplify app stay. The live ids `dliv`, `apps-893`, `met893`, `dropbox893`, and `calendar893` are refused.

`scripts/site-aws.test.sh` runs both scripts against a fake AWS CLI.

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

Written to the repo root by `deploy.sh`. Gitignored — never committed. Dropbox, calendar, PDF search, and video convert copy the pool id and bucket names from this file into their own `config.ts`. Their `id` comes from `base/bin/config.ts` when they omit it. The mileage tracker reads this file through `BASE_OUTPUTS_PATH`.

`auth.user_pool_client_id` here is `{id}-app-client`. The website does not use it. After `dropbox-893` deploys, the website takes `USER_POOL_CLIENT_ID` from `auth.user_pool_client_id` in `dropbox_outputs.json` (`{id}-dropbox-client`). The pool id in both files is the same pool.

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
│       └── check-stack.sh      ← older base-stack check; use validate-site.sh
├── scripts/
│   ├── new-site.sh             ← clone a new id, then ask before each deploy
│   ├── new-site.test.sh        ← prompt checks, no AWS
│   ├── validate-site.sh        ← report stacks and resources for this id
│   ├── destroy-site.sh         ← delete those stacks and retained resources
│   └── site-aws.test.sh        ← fake-AWS checks for validate and destroy
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
