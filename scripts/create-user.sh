#!/bin/bash
# scripts/create-user.sh
# Create one sign-in user in this site's Cognito user pool.
# The pool id comes from dropbox_outputs.json. Self sign-up is off.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SITE_CONFIG_FILE:-${REPO_ROOT}/base/bin/config.ts}"
SITE_DIR="${SITE_PARENT:-$(cd "${REPO_ROOT}/.." && pwd)}"

config_field() {
  grep -E "^[[:space:]]+$2:" "$1" | head -1 | sed 's/.*"\([^"]*\)".*/\1/'
}

password_ok() {
  local password="$1"
  [ "${#password}" -ge 8 ] || return 1
  printf '%s' "$password" | grep -q '[a-z]' || return 1
  printf '%s' "$password" | grep -q '[A-Z]' || return 1
  printf '%s' "$password" | grep -q '[0-9]' || return 1
  printf '%s' "$password" | grep -q '[^A-Za-z0-9]' || return 1
  return 0
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            Create one Cognito user           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
  echo "  base/bin/config.ts not found: $CONFIG_FILE"
  exit 1
fi
ID="$(config_field "$CONFIG_FILE" id)"
AWS_REGION="$(config_field "$CONFIG_FILE" awsRegion)"
if [ -z "$ID" ] || [ -z "$AWS_REGION" ]; then
  echo "  Could not read id and awsRegion from $CONFIG_FILE"
  exit 1
fi
case "$ID" in
  dliv|apps-893|met893|your-id-here|dropbox893|calendar893)
    echo "  '$ID' is a live site id. This script will not create a user there."
    exit 1
    ;;
esac

DROPBOX_OUT="${SITE_DIR}/dropbox-893/dropbox_outputs.json"
if [ ! -f "$DROPBOX_OUT" ]; then
  echo "  Dropbox outputs are missing: $DROPBOX_OUT"
  echo "  Deploy dropbox-893 first. The website signs in with that pool."
  exit 1
fi
POOL_ID="$(python3 -c 'import json,sys; print((json.load(open(sys.argv[1])).get("auth") or {}).get("user_pool_id") or "")' "$DROPBOX_OUT")"
if [ -z "$POOL_ID" ]; then
  echo "  dropbox_outputs.json has no auth.user_pool_id."
  exit 1
fi

if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  An AWS administrator account is required, with keys installed."
  echo "  Run aws configure, then run this again."
  exit 1
fi

echo "  Site: ${ID}"
echo "  Pool: ${POOL_ID}"
echo "  Region: ${AWS_REGION}"
echo "  Password: 8 or more characters, with upper, lower, a number, and a symbol."
echo ""

read -r -p "  Email: " USER_EMAIL || exit 1
if ! printf '%s' "$USER_EMAIL" | grep -q '@'; then
  echo "  Email must contain @."
  exit 1
fi
while true; do
  read -r -s -p "  Permanent password: " USER_PASSWORD || exit 1
  echo ""
  if password_ok "$USER_PASSWORD"; then
    break
  fi
  echo "  That password does not meet the pool policy. Try again."
done
read -r -p "  Create ${USER_EMAIL} in ${POOL_ID}? (y/n): " CONFIRM || exit 1
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "  Cancelled."
  exit 1
fi

TEMP_PASSWORD="$(python3 -c 'import secrets,string; chars=string.ascii_letters+string.digits; print("Tmp"+"".join(secrets.choice(chars) for _ in range(12))+"aA1!")')"

echo ""
echo "  CLI: aws cognito-idp admin-create-user --user-pool-id ${POOL_ID} --username ${USER_EMAIL} --region ${AWS_REGION}"
set +e
CREATE_ERR="$(aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username "$USER_EMAIL" \
  --temporary-password "$TEMP_PASSWORD" \
  --message-action SUPPRESS \
  --region "$AWS_REGION" 2>&1 >/dev/null)"
CREATE_STATUS=$?
set -e
if [ "$CREATE_STATUS" -ne 0 ]; then
  if printf '%s' "$CREATE_ERR" | grep -q 'UsernameExistsException'; then
    echo "  User already exists. Setting the permanent password."
  else
    echo "  ${CREATE_ERR}"
    exit 1
  fi
fi

echo "  CLI: aws cognito-idp admin-set-user-password --user-pool-id ${POOL_ID} --username ${USER_EMAIL} --permanent --region ${AWS_REGION}"
aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "$USER_EMAIL" \
  --password "$USER_PASSWORD" \
  --permanent \
  --region "$AWS_REGION"
echo ""
echo "  ${USER_EMAIL} can sign in. The password is permanent, so the site will not ask for a new one."
echo ""
