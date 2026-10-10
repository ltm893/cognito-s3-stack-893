#!/bin/bash
# base/scripts/deploy.sh
# Deploys the Cognito + S3 base stack and writes base_outputs.json at repo root.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../bin/config.ts"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║   cognito-s3-stack-893 — Base Deploy     ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── Check config.ts exists ────────────────────────────────────────────────────
if [ ! -f "$CONFIG_FILE" ]; then
  echo "  ❌ bin/config.ts not found."
  echo "     Run: cp base/bin/config.example.ts base/bin/config.ts"
  echo "     Then fill in your values and re-run this script."
  exit 1
fi

# ── Read id + region directly from config.ts via grep ────────────────────────
CONFIG_ID=$(grep -E '^\s+id:' "$CONFIG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
AWS_REGION=$(grep -E '^\s+awsRegion:' "$CONFIG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
USER_POOL_NAME=$(grep -E '^\s+userPoolName:' "$CONFIG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')
FROM_EMAIL=$(grep -E '^\s+fromEmail:' "$CONFIG_FILE" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$CONFIG_ID" ]; then
  echo "  ❌ Could not read id from config.ts. Make sure it is set correctly."
  exit 1
fi

# Stack name includes config.id so multiple deployments on the same AWS account don't collide
STACK_NAME="CognitoS3BaseStack-${CONFIG_ID}"

echo "  Stack:         $STACK_NAME"
echo "  Region:        $AWS_REGION"
echo "  ID prefix:     $CONFIG_ID"
echo "  User Pool:     $USER_POOL_NAME"
echo "  From email:    $FROM_EMAIL"
echo ""
echo "  AWS resources that will be created:"
echo "    S3:      ${CONFIG_ID}-public, ${CONFIG_ID}-private"
echo "    Cognito: ${USER_POOL_NAME}"
echo ""
read -p "  Proceed with deploy? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then echo "  Cancelled."; exit 0; fi

# ── Install + deploy ──────────────────────────────────────────────────────────
cd "${SCRIPT_DIR}/.."
[ ! -d "node_modules" ] && npm install

echo ""
echo "  Running cdk deploy..."
npx cdk deploy --require-approval never

# ── Read CloudFormation outputs ───────────────────────────────────────────────
echo ""
echo "  Reading stack outputs..."

get_output() {
  aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text
}

AWS_REGION_OUT=$(get_output "AwsRegion")
USER_POOL_ID=$(get_output "UserPoolId")
USER_POOL_CLIENT_ID=$(get_output "UserPoolClientId")
USER_POOL_PROVIDER=$(get_output "UserPoolProviderName")
IDENTITY_POOL_ID=$(get_output "IdentityPoolId")
AUTH_ROLE_ARN=$(get_output "AuthRoleArn")
PUBLIC_BUCKET=$(get_output "PublicBucketName")
PRIVATE_BUCKET=$(get_output "PrivateBucketName")

# ── Write base_outputs.json to repo root ─────────────────────────────────────
echo "  Writing base_outputs.json to repo root..."

cat > "${REPO_ROOT}/base_outputs.json" << EOF
{
  "version": "1",
  "aws_region": "${AWS_REGION_OUT}",
  "auth": {
    "user_pool_id":        "${USER_POOL_ID}",
    "user_pool_client_id": "${USER_POOL_CLIENT_ID}",
    "user_pool_provider":  "${USER_POOL_PROVIDER}",
    "identity_pool_id":    "${IDENTITY_POOL_ID}",
    "auth_role_arn":       "${AUTH_ROLE_ARN}"
  },
  "storage": {
    "public_bucket":  "${PUBLIC_BUCKET}",
    "private_bucket": "${PRIVATE_BUCKET}"
  }
}
EOF

echo ""
echo "  ✅ base_outputs.json written"
echo ""
echo "  ────────────────────────────────────────────────────"
echo "  User Pool ID:    $USER_POOL_ID"
echo "  App Client ID:   $USER_POOL_CLIENT_ID"
echo "  Identity Pool:   $IDENTITY_POOL_ID"
echo "  Public Bucket:   $PUBLIC_BUCKET"
echo "  Private Bucket:  $PRIVATE_BUCKET"
echo "  ────────────────────────────────────────────────────"
echo ""
echo "  Next: deploy an add-on, e.g.:"
echo "    BASE_OUTPUTS_PATH=\$(pwd)/base_outputs.json <addon>/backend/scripts/deploy.sh"
echo ""
