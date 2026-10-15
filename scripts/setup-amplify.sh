#!/bin/bash
# scripts/setup-amplify.sh
# Create the Amplify Hosting app for this site from the add-on outputs files.
# The AWS CLI sets the branch environment variables. Connecting GitHub needs a
# personal access token; otherwise the script prints the console steps.
# Does not use dliv-web. Does not deploy CDK.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SITE_CONFIG_FILE:-${REPO_ROOT}/base/bin/config.ts}"
SITE_DIR="${SITE_PARENT:-$(cd "${REPO_ROOT}/.." && pwd)}"
DEFAULT_REPO="https://github.com/ltm893/web-app-893"

config_field() {
  grep -E "^[[:space:]]+$2:" "$1" | head -1 | sed 's/.*"\([^"]*\)".*/\1/'
}

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║              Amplify hosting setup           ║"
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
    echo "  '$ID' is a live site id. This script will not create an Amplify app for it."
    exit 1
    ;;
esac

DROPBOX_OUT="${SITE_DIR}/dropbox-893/dropbox_outputs.json"
CAL_OUT="${SITE_DIR}/calendar-893/calendar_outputs.json"
PDF_OUT="${SITE_DIR}/pdf-search-893/pdf_search_outputs.json"
VIDEO_OUT="${SITE_DIR}/video-convert-893/video_convert_outputs.json"

if [ ! -f "$DROPBOX_OUT" ]; then
  echo "  Dropbox outputs are missing: $DROPBOX_OUT"
  echo "  Deploy dropbox-893 first. The website client id comes from that file."
  exit 1
fi

if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  An AWS administrator account is required, with keys installed."
  echo "  Run aws configure, then run this again."
  exit 1
fi

echo "  Site folder: ${SITE_DIR}"
echo "  Amplify app name: ${ID}"
echo "  Region: ${AWS_REGION}"
echo "  Repository default: ${DEFAULT_REPO}"
echo "  Do not point this app at dliv-web."
echo ""

read -r -p "  Site title [${ID}]: " SITE_TITLE || exit 1
SITE_TITLE="${SITE_TITLE:-$ID}"
read -r -p "  Tagline [Family & Friends]: " SITE_TAGLINE || exit 1
SITE_TAGLINE="${SITE_TAGLINE:-Family & Friends}"
read -r -p "  Footer [${SITE_TITLE}]: " SITE_FOOTER || exit 1
SITE_FOOTER="${SITE_FOOTER:-$SITE_TITLE}"
read -r -p "  Shared label [All users]: " SITE_SHARED || exit 1
SITE_SHARED="${SITE_SHARED:-All users}"
read -r -p "  GitHub repo [${DEFAULT_REPO}]: " GH_REPO || exit 1
GH_REPO="${GH_REPO:-$DEFAULT_REPO}"
case "$GH_REPO" in
  *dliv-web*)
    echo "  Use web-app-893. dliv-web is the live site and is not the template."
    exit 1
    ;;
esac
read -r -p "  Git branch [dev]: " GH_BRANCH || exit 1
GH_BRANCH="${GH_BRANCH:-dev}"
echo "  A GitHub personal access token with repo scope connects the repository."
echo "  Create one at https://github.com/settings/tokens"
echo "  Press enter to skip the token and connect the repository in the Amplify console."
read -r -s -p "  GitHub token: " GH_TOKEN || exit 1
echo ""

ENV_JSON="$(mktemp)"
APP_JSON="$(mktemp)"
BRANCH_JSON="$(mktemp)"
trap 'rm -f "$ENV_JSON" "$APP_JSON" "$BRANCH_JSON"' EXIT

python3 - "$DROPBOX_OUT" "$CAL_OUT" "$PDF_OUT" "$VIDEO_OUT" "$ENV_JSON" \
  "$SITE_TITLE" "$SITE_TAGLINE" "$SITE_FOOTER" "$SITE_SHARED" <<'PY'
import json, sys
drop_path, cal_path, pdf_path, video_path, out_path, title, tagline, footer, shared = sys.argv[1:10]
drop = json.load(open(drop_path))
url = ((drop.get("api") or {}).get("base_url") or "").strip()
client = ((drop.get("auth") or {}).get("user_pool_client_id") or "").strip()
pool = ((drop.get("auth") or {}).get("user_pool_id") or "").strip()
region = (drop.get("aws_region") or "").strip()
if not url.startswith("https://") or not client or not pool or not region:
    sys.stderr.write("dropbox_outputs.json needs aws_region, the Dropbox client id, and an https API URL.\n")
    sys.exit(1)
env = {
    "APP_REGION": region,
    "USER_POOL_ID": pool,
    "USER_POOL_CLIENT_ID": client,
    "DROPBOX_API_URL": url,
    "SITE_TITLE": title,
    "SITE_TAGLINE": tagline,
    "SITE_FOOTER": footer,
    "SITE_SHARED_LABEL": shared,
}
def add_api(path, key):
    try:
        data = json.load(open(path))
    except FileNotFoundError:
        return
    api = ((data.get("api") or {}).get("base_url") or "").strip()
    if api.startswith("https://"):
        env[key] = api
add_api(cal_path, "CALENDAR_API_URL")
add_api(pdf_path, "PDF_SEARCH_API_URL")
add_api(video_path, "VIDEO_CONVERT_API_URL")
json.dump(env, open(out_path, "w"))
PY

echo ""
echo "  Environment variables from the outputs files:"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1]));
[print("    "+k) for k in d]' "$ENV_JSON"
echo ""
if [ -n "$GH_TOKEN" ]; then
  echo "  GitHub: this script connects ${GH_REPO} branch ${GH_BRANCH}."
else
  echo "  GitHub: you connect ${GH_REPO} branch ${GH_BRANCH} in the console."
fi
read -r -p "  Create the Amplify app? (y/n): " CONFIRM || exit 1
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "  Cancelled."
  exit 1
fi

STAGE="DEVELOPMENT"
if [ "$GH_BRANCH" = "main" ]; then
  STAGE="PRODUCTION"
fi

python3 - "$APP_JSON" "$ID" "$GH_REPO" "$GH_TOKEN" "$ENV_JSON" <<'PY'
import json, sys
out_path, name, repo, token, env_path = sys.argv[1:6]
body = {
    "name": name,
    "platform": "WEB",
    "enableBranchAutoBuild": True,
    "environmentVariables": json.load(open(env_path)),
}
if token:
    body["repository"] = repo
    body["accessToken"] = token
json.dump(body, open(out_path, "w"))
PY

echo ""
echo "  CLI: aws amplify list-apps --region ${AWS_REGION}"
APPS_JSON="$(aws amplify list-apps --region "$AWS_REGION" --output json)"
APP_ID="$(python3 -c 'import json,sys; want=sys.argv[1]; data=json.load(sys.stdin);
print(next((a.get("appId","") for a in data.get("apps") or [] if a.get("name")==want), ""))' "$ID" <<<"$APPS_JSON")"

if [ -z "$APP_ID" ]; then
  echo "  CLI: aws amplify create-app --name ${ID} --platform WEB --region ${AWS_REGION}"
  CREATE_JSON="$(aws amplify create-app --region "$AWS_REGION" --cli-input-json "file://${APP_JSON}" --output json)"
  APP_ID="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["app"]["appId"])' <<<"$CREATE_JSON")"
  echo "  Created app: ${APP_ID}"
else
  echo "  Amplify app already exists: ${APP_ID}"
  echo "  CLI: aws amplify update-app --app-id ${APP_ID} --region ${AWS_REGION}"
  python3 - "$APP_JSON" "$APP_ID" "$ENV_JSON" "$GH_REPO" "$GH_TOKEN" <<'PY'
import json, sys
out_path, app_id, env_path, repo, token = sys.argv[1:6]
body = {"appId": app_id, "environmentVariables": json.load(open(env_path))}
if token:
    body["repository"] = repo
    body["accessToken"] = token
json.dump(body, open(out_path, "w"))
PY
  aws amplify update-app --region "$AWS_REGION" --cli-input-json "file://${APP_JSON}" --output json >/dev/null
fi

BRANCH_EXISTS=no
if aws amplify get-branch --app-id "$APP_ID" --branch-name "$GH_BRANCH" --region "$AWS_REGION" --output json >/dev/null 2>&1; then
  BRANCH_EXISTS=yes
fi

python3 - "$BRANCH_JSON" "$APP_ID" "$GH_BRANCH" "$STAGE" "$ENV_JSON" <<'PY'
import json, sys
out_path, app_id, branch, stage, env_path = sys.argv[1:6]
json.dump({
    "appId": app_id,
    "branchName": branch,
    "stage": stage,
    "enableAutoBuild": True,
    "environmentVariables": json.load(open(env_path)),
}, open(out_path, "w"))
PY

if [ "$BRANCH_EXISTS" = "yes" ]; then
  echo "  CLI: aws amplify update-branch --app-id ${APP_ID} --branch-name ${GH_BRANCH} --region ${AWS_REGION}"
  aws amplify update-branch --region "$AWS_REGION" --cli-input-json "file://${BRANCH_JSON}" --output json >/dev/null
else
  echo "  CLI: aws amplify create-branch --app-id ${APP_ID} --branch-name ${GH_BRANCH} --region ${AWS_REGION}"
  aws amplify create-branch --region "$AWS_REGION" --cli-input-json "file://${BRANCH_JSON}" --output json >/dev/null
fi

CONSOLE_URL="https://${AWS_REGION}.console.aws.amazon.com/amplify/apps/${APP_ID}"
SITE_URL="https://${GH_BRANCH}.${APP_ID}.amplifyapp.com"

if [ -n "$GH_TOKEN" ]; then
  echo "  CLI: aws amplify start-job --app-id ${APP_ID} --branch-name ${GH_BRANCH} --job-type RELEASE --region ${AWS_REGION}"
  aws amplify start-job --app-id "$APP_ID" --branch-name "$GH_BRANCH" --job-type RELEASE --region "$AWS_REGION" --output json >/dev/null
  echo ""
  echo "  Console — watch the build"
  echo "  1. Open ${CONSOLE_URL}"
  echo "  2. Wait until branch ${GH_BRANCH} is green."
  echo "  3. Open ${SITE_URL}"
  echo "  4. Hosting, Custom domains, only after that URL loads."
else
  echo ""
  echo "  Console — connect the repository"
  echo "  1. Open ${CONSOLE_URL}"
  echo "  2. Choose Hosting, then Connect branch."
  echo "  3. Authorize GitHub."
  echo "  4. Repository: ${GH_REPO}"
  echo "     Branch: ${GH_BRANCH}"
  echo "  5. Leave the build spec as amplify.yml. Do not add a CDK deploy."
  echo "  6. The environment variables are already on branch ${GH_BRANCH}."
  echo "     Save and start the build."
  echo "  7. Open ${SITE_URL} when the build is green."
  echo "  8. Hosting, Custom domains, only after that URL loads."
fi

echo ""
read -r -p "  Create a sign-in user now? (y/n): " MAKE_USER || exit 1
if [[ "$MAKE_USER" != "y" && "$MAKE_USER" != "Y" ]]; then
  echo "  Sign-in user skipped. The pool does not allow self sign-up."
  echo ""
  exit 0
fi
read -r -p "  Email: " USER_EMAIL || exit 1
read -r -s -p "  Permanent password: " USER_PASSWORD || exit 1
echo ""
POOL_ID="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["USER_POOL_ID"])' "$ENV_JSON")"
echo "  CLI: aws cognito-idp admin-create-user --user-pool-id ${POOL_ID} --username ${USER_EMAIL} --region ${AWS_REGION}"
aws cognito-idp admin-create-user \
  --user-pool-id "$POOL_ID" \
  --username "$USER_EMAIL" \
  --temporary-password "$USER_PASSWORD" \
  --message-action SUPPRESS \
  --region "$AWS_REGION" >/dev/null
echo "  CLI: aws cognito-idp admin-set-user-password --user-pool-id ${POOL_ID} --username ${USER_EMAIL} --permanent --region ${AWS_REGION}"
aws cognito-idp admin-set-user-password \
  --user-pool-id "$POOL_ID" \
  --username "$USER_EMAIL" \
  --password "$USER_PASSWORD" \
  --permanent \
  --region "$AWS_REGION"
echo "  User ${USER_EMAIL} can sign in at ${SITE_URL}"
echo ""
