#!/bin/bash
# base/scripts/check-stack.sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/.."

STACK_NAME="CognitoS3BaseStack"
AWS_REGION=$(node -e "const {config} = require('./bin/config'); console.log(config.awsRegion)" 2>/dev/null || echo "us-east-1")

echo ""
echo "╔══════════════════════════════════════╗"
echo "║      Check Base Stack Status         ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "  Stack: $STACK_NAME  |  Region: $AWS_REGION"
echo ""

STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" --region "$AWS_REGION" \
  --query "Stacks[0].StackStatus" --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [[ "$STATUS" == "DOES_NOT_EXIST" || "$STATUS" == "None" ]]; then
  echo "  ❌ Stack not deployed."
  echo "     Run: ./scripts/deploy.sh"
  echo ""; exit 0
fi

echo "  Status: $STATUS"
echo ""

get_output() {
  aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$AWS_REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text 2>/dev/null
}

echo "  User Pool ID:    $(get_output UserPoolId)"
echo "  App Client ID:   $(get_output UserPoolClientId)"
echo "  Identity Pool:   $(get_output IdentityPoolId)"
echo "  Public Bucket:   $(get_output PublicBucketName)"
echo "  Private Bucket:  $(get_output PrivateBucketName)"
echo ""
