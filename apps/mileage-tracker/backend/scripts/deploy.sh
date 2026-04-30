#!/bin/bash
# apps/mileage-tracker/backend/scripts/deploy.sh
# Deploys the Mileage Tracker add-on and writes met_outputs.json
set -e

STACK_NAME="MileageTrackerStack"
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AWS_REGION=$(node -e "const b=require('${REPO_ROOT}/base_outputs.json'); console.log(b.aws_region)" 2>/dev/null || echo "us-east-1")

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║    Mileage Tracker — Add-on Deploy       ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [ ! -f "${REPO_ROOT}/base_outputs.json" ]; then
  echo "  ❌ base_outputs.json not found at repo root."
  echo "     Deploy the base stack first: cd base && ./scripts/deploy.sh"
  exit 1
fi

echo "  Stack:     $STACK_NAME"
echo "  Region:    $AWS_REGION"
echo "  Base from: $REPO_ROOT/base_outputs.json"
echo ""
read -p "  Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then echo "  Cancelled."; exit 0; fi

[ ! -d "node_modules" ] && npm install

echo ""
npx cdk deploy --require-approval never

get_output() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

API_URL=$(get_output "ApiUrl")
USER_POOL_ID=$(get_output "UserPoolId")
APP_CLIENT_ID=$(get_output "AppClientId")
IDENTITY_POOL_ID=$(get_output "IdentityPoolId")
RECEIPTS_BUCKET=$(get_output "ReceiptsBucket")
VEHICLES_TABLE=$(get_output "VehiclesTable")
TRIPS_TABLE=$(get_output "TripsTable")
EXPENSES_TABLE=$(get_output "ExpensesTable")

cat > "${REPO_ROOT}/apps/mileage-tracker/met_outputs.json" << EOF
{
  "version": "1",
  "api": {
    "aws_region": "${AWS_REGION}",
    "base_url":   "${API_URL}"
  },
  "auth": {
    "aws_region":          "${AWS_REGION}",
    "user_pool_id":        "${USER_POOL_ID}",
    "user_pool_client_id": "${APP_CLIENT_ID}",
    "identity_pool_id":    "${IDENTITY_POOL_ID}"
  },
  "storage": {
    "aws_region":      "${AWS_REGION}",
    "receipts_bucket": "${RECEIPTS_BUCKET}"
  },
  "tables": {
    "vehicles": "${VEHICLES_TABLE}",
    "trips":    "${TRIPS_TABLE}",
    "expenses": "${EXPENSES_TABLE}"
  }
}
EOF

echo ""
echo "  ✅ met_outputs.json written to apps/mileage-tracker/"
echo "  API URL:         $API_URL"
echo "  User Pool:       $USER_POOL_ID"
echo "  App Client:      $APP_CLIENT_ID"
echo "  Identity Pool:   $IDENTITY_POOL_ID"
echo "  Receipts Bucket: $RECEIPTS_BUCKET"
echo ""
