# cognito-s3-stack-893

A reusable AWS CDK monorepo providing a foundation of Cognito auth + S3 storage, with reference app implementations built on top.

## What this is

`cognito-s3-stack-893` is the base infrastructure stack that powers invite-only AWS applications. Deploy it once, then deploy any number of add-on apps that share the same auth and storage layer.

## Structure

```
cognito-s3-stack-893/
├── base/                        ← deploy first — Cognito + S3 + IAM
├── apps/
│   ├── music-player/            ← S3 music streaming app (iOS)
│   │   ├── backend/             ← Lambda: file listing, presigned URLs
│   │   └── ios/                 ← SwiftUI iOS app
│   └── mileage-tracker/         ← Mileage & expense tracker (iOS)
│       ├── backend/             ← DynamoDB + API Gateway + Lambda
│       └── ios/                 ← SwiftUI iOS app
└── shared/
    └── types/                   ← Shared TypeScript types
```

## How it works

```
1. Deploy base/        →  creates Cognito, S3, IAM
                           writes base_outputs.json at repo root

2. Deploy an app/      →  reads base_outputs.json
                           deploys app-specific resources (DynamoDB, Lambda, etc.)
                           writes app-specific outputs (met_outputs.json etc.)

3. Build mobile app    →  reads app outputs for config
```

## Prerequisites

Before deploying anything you need:

- **AWS CLI** configured with your account (`aws configure`)
- **AWS CDK** bootstrapped in your region (`npx cdk bootstrap`)
- **Node.js** 20+ (`node --version`)
- An AWS account with appropriate IAM permissions

## Quick start

```bash
# 1. Clone the repo
git clone https://github.com/ltm893/cognito-s3-stack-893.git
cd cognito-s3-stack-893

# 2. Set up base config
cp base/bin/config.example.ts base/bin/config.ts
# Edit base/bin/config.ts with your values

# 3. Deploy base
cd base
chmod +x scripts/*.sh
npm install
./scripts/deploy.sh
# → writes base_outputs.json at repo root

# 4. Deploy an app (e.g. mileage tracker)
cd ../apps/mileage-tracker/backend
npm install
./scripts/deploy.sh
# → writes apps/mileage-tracker/met_outputs.json
```

## Real-world implementation

This stack powers [dliv.com](https://dliv.com) — a private family photo and file sharing site. dliv.com is a separate repo that consumes `cognito-s3-stack-893` as its foundation.

## Estimated AWS costs

All resources use pay-per-request or free tier where possible.

| Service | Free tier | Est. cost at low usage |
|---|---|---|
| Cognito | 50,000 MAUs free | $0 |
| S3 | 5GB free | ~$0.023/GB/month |
| Lambda | 1M calls/month free | $0 |
| API Gateway | 1M calls/month free | $0 |
| DynamoDB | 25GB + 200M req free | $0 |
| Textract | No free tier | $0.0015/page |
