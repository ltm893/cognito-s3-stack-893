#!/bin/bash
# apps/music-player/backend/scripts/deploy.sh
set -e

STACK_NAME="MusicPlayerStack"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AWS_REGION=$(node -e "const b=require('${REPO_ROOT}/base_outputs.json'); console.log(b.aws_region)" 2>/dev/null || echo "us-east-1")

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     Music Player — Add-on Deploy         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

if [ ! -f "${REPO_ROOT}/base_outputs.json" ]; then
  echo "  ❌ base_outputs.json not found."
  echo "     Run: cd base && ./scripts/deploy.sh"; exit 1
fi

echo "  Stack: $STACK_NAME  |  Region: $AWS_REGION"
echo ""
read -p "  Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then echo "  Cancelled."; exit 0; fi

cd "${SCRIPT_DIR}/.."
[ ! -d "node_modules" ] && npm install

echo ""
npx cdk deploy --require-approval never

get_output() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

cat > "${REPO_ROOT}/apps/music-player/music_outputs.json" << EOF
{
  "version": "1",
  "api": { "aws_region": "${AWS_REGION}", "base_url": "$(get_output ApiUrl)" },
  "auth": {
    "aws_region":          "${AWS_REGION}",
    "user_pool_id":        "$(get_output UserPoolId)",
    "user_pool_client_id": "$(get_output AppClientId)"
  },
  "storage": { "aws_region": "${AWS_REGION}", "private_bucket": "$(get_output PrivateBucket)" }
}
EOF

echo ""
echo "  ✅ music_outputs.json written to apps/music-player/"
echo "  API URL:    $(get_output ApiUrl)"
echo ""
