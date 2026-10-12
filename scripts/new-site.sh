#!/bin/bash
# scripts/new-site.sh
# Ask for a site id, clone cognito-s3-stack-893 into ~/Dev/projects/<id>/,
# and write its config.ts. Offer to deploy that base stack, then each add-on
# after its config.ts is written. Does not clone dliv-web.
#
# Usage:
#   ./scripts/new-site.sh

set -euo pipefail

PARENT="${NEW_SITE_PARENT:-$HOME/Dev/projects}"
GITHUB="https://github.com/ltm893"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            New site — base repo first        ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  The id is the name of this site."
echo "  It becomes the folder ~/Dev/projects/<id>/"
echo "  and the id in cognito-s3-stack-893/base/bin/config.ts."
echo "  The user pool is <id>-app-users."
echo "  The buckets are <id>-public and <id>-private."
echo "  The git directory inside that folder stays cognito-s3-stack-893."
echo "  Deploying needs an AWS administrator account with keys installed (aws configure)."
echo ""

while true; do
  read -r -p "  Id: " ID || exit 1
  ID="$(echo "$ID" | tr -d '[:space:]')"
  if ! [[ "$ID" =~ ^[a-z0-9]([a-z0-9-]{0,53}[a-z0-9])?$ ]]; then
    echo "  Use 1–55 characters: lowercase letters, numbers, and hyphens. Do not start or end with a hyphen."
    continue
  fi
  case "$ID" in
    dliv|apps-893|met893|your-id-here)
      echo "  '$ID' is reserved. Pick another id."
      continue
      ;;
  esac
  break
done

DEST="${PARENT}/${ID}"
BASE_REPO="${DEST}/cognito-s3-stack-893"
BASE_CONFIG="${BASE_REPO}/base/bin/config.ts"
BASE_OUTPUTS="${BASE_REPO}/base_outputs.json"

clone_repo() {
  local repo="$1"
  local target="${DEST}/${repo}"
  if [ -d "${target}/.git" ]; then
    echo "  ${repo} is already in ${DEST}"
    return
  fi
  echo ""
  echo "  Cloning ${repo}..."
  git clone --branch dev "${GITHUB}/${repo}.git" "$target"
}

fill_base_config() {
  python3 - "$BASE_CONFIG" "$ID" "$FROM_EMAIL" <<'PY'
import sys
from pathlib import Path

path, site_id, email = sys.argv[1:]
file = Path(path)
text = file.read_text()
text = text.replace("your-id-here", site_id)
text = text.replace("noreply@yourdomain.com", email)
file.write_text(text)
PY
}

fill_addon_config() {
  local repo="$1"
  python3 - "$DEST" "$repo" "$ID" "$BASE_CONFIG" "$BASE_OUTPUTS" <<'PY'
import json
import sys
from pathlib import Path

dest, repo, site_id, base_config, base_outputs = sys.argv[1:]
config = Path(dest) / repo / "backend" / "bin" / "config.ts"
text = config.read_text()
text = text.replace("your-id-here", site_id)

pool = ""
public_bucket = f"{site_id}-public"
private_bucket = f"{site_id}-private"
region = ""
outputs = Path(base_outputs)
if outputs.is_file():
    data = json.loads(outputs.read_text())
    pool = str(data.get("auth", {}).get("user_pool_id", "")).strip()
    public_bucket = str(data.get("storage", {}).get("public_bucket", "")).strip() or public_bucket
    private_bucket = str(data.get("storage", {}).get("private_bucket", "")).strip() or private_bucket
    region = str(data.get("aws_region", "")).strip()

base_text = Path(base_config).read_text() if Path(base_config).is_file() else ""
if not region:
    for line in base_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("awsRegion:"):
            region = stripped.split('"')[1]
            break

if region:
    text = text.replace('awsRegion: "us-east-1"', f'awsRegion: "{region}"', 1)
if pool:
    text = text.replace('userPoolId: "us-east-1_XXXXXXXXX"', f'userPoolId: "{pool}"', 1)

if repo == "dropbox-893":
    text = text.replace(f'privateBucket: "{site_id}-private"', f'privateBucket: "{private_bucket}"', 1)
    text = text.replace(f'publicBucket: "{site_id}-public"', f'publicBucket: "{public_bucket}"', 1)
elif repo == "pdf-search-893":
    text = text.replace(f'docsBucket: "{site_id}-private"', f'docsBucket: "{private_bucket}"', 1)
elif repo == "video-convert-893":
    text = text.replace(f'privateBucket: "{site_id}-private"', f'privateBucket: "{private_bucket}"', 1)

config.write_text(text)
print("pool-filled" if pool else "pool-missing")
PY
}

aws_keys_ready() {
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    echo "  An AWS administrator account is required, with keys installed."
    echo "  Run aws configure, then deploy again."
    return 1
  fi
  return 0
}

offer_deploy() {
  local label="$1"
  local dir="$2"
  echo ""
  read -r -p "  Deploy ${label} now? (y/n): " DEPLOY || exit 1
  if [[ "$DEPLOY" != "y" && "$DEPLOY" != "Y" ]]; then
    echo "  Skipped deploy of ${label}."
    return 1
  fi
  if ! aws_keys_ready; then
    return 1
  fi
  if [[ "$dir" == */video-convert-893/backend ]]; then
    if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
      echo "  Docker is not running. video-convert builds the Fargate image locally."
      echo "  Start Docker Desktop, or run: colima start"
      echo "  Then choose 4 again."
      return 1
    fi
  fi
  echo "  Running ${dir}/scripts/deploy.sh"
  echo "  That script asks again before it creates AWS resources."
  if (cd "$dir" && ./scripts/deploy.sh); then
    echo "  Deploy finished: ${label}"
    return 0
  fi
  echo "  Deploy stopped: ${label}"
  return 1
}

write_addon() {
  local repo="$1"
  local config="${DEST}/${repo}/backend/bin/config.ts"
  local example="${DEST}/${repo}/backend/bin/config.example.ts"
  clone_repo "$repo"
  if [ -f "$config" ]; then
    read -r -p "  ${repo} config.ts already exists. Replace it? (y/n): " REPLACE || exit 1
    if [[ "$REPLACE" != "y" && "$REPLACE" != "Y" ]]; then
      echo "  Left ${config} in place."
    else
      cp "$example" "$config"
      echo "  Wrote ${config}"
    fi
  else
    cp "$example" "$config"
    echo "  Wrote ${config}"
  fi
  local pool_state
  pool_state="$(fill_addon_config "$repo")"
  if [ "$pool_state" = "pool-missing" ]; then
    echo "  userPoolId is still a placeholder. The base stack has not written base_outputs.json."
    offer_deploy "the Cognito base stack" "${BASE_REPO}/base" || true
    if [ -f "$BASE_OUTPUTS" ]; then
      pool_state="$(fill_addon_config "$repo")"
    fi
  fi
  if [ "$pool_state" != "pool-filled" ]; then
    echo "  Skipped deploy of ${repo} until the base stack has a pool id."
    return
  fi
  echo "  userPoolId was copied from base_outputs.json."
  if [ "$repo" = "calendar-893" ]; then
    echo "  The table defaults to ${ID}-calendar and createTable defaults to true."
    echo "  After this deploy succeeds, set createTable to false."
  fi
  offer_deploy "${repo}" "${DEST}/${repo}/backend" || true
}

if [ ! -d "${BASE_REPO}/.git" ]; then
  echo ""
  echo "  From email Cognito will use for invites."
  echo "  SES must accept this address or invite mail will not send."
  read -r -p "  From email [noreply@yourdomain.com]: " FROM_EMAIL || exit 1
  FROM_EMAIL="${FROM_EMAIL:-noreply@yourdomain.com}"

  echo ""
  echo "  Folder:     $DEST"
  echo "  Base repo:  ${BASE_REPO}"
  echo "  Config id:  $ID"
  echo "  Pool name:  ${ID}-app-users"
  echo "  From email: $FROM_EMAIL"
  echo ""
  read -r -p "  Create this base repo and config.ts? (y/n): " CONFIRM || exit 1
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "  Cancelled."
    exit 0
  fi
  mkdir -p "$DEST"
  clone_repo "cognito-s3-stack-893"
  cp "${BASE_REPO}/base/bin/config.example.ts" "$BASE_CONFIG"
  fill_base_config
  echo ""
  echo "  Wrote ${BASE_CONFIG}"
  offer_deploy "the Cognito base stack" "${BASE_REPO}/base" || true
else
  echo ""
  echo "  Base repo already exists: ${BASE_REPO}"
  if [ ! -f "$BASE_CONFIG" ]; then
    echo "  Base config.ts is missing. Copy the example and set id to ${ID} before choosing an add-on."
    exit 1
  fi
  echo "  Config: ${BASE_CONFIG}"
  if [ -f "$BASE_OUTPUTS" ]; then
    echo "  base_outputs.json is already written."
  else
    offer_deploy "the Cognito base stack" "${BASE_REPO}/base" || true
  fi
fi

echo ""
echo "  Add-ons. Each choice clones that repo into ${DEST} and writes its config.ts."
while true; do
  echo ""
  echo "  1) dropbox-893"
  echo "  2) calendar-893"
  echo "  3) pdf-search-893"
  echo "  4) video-convert-893  (needs dropbox-893)"
  echo "  5) done"
  read -r -p "  Choose an add-on: " CHOICE || exit 1
  case "$CHOICE" in
    1) write_addon "dropbox-893" ;;
    2) write_addon "calendar-893" ;;
    3) write_addon "pdf-search-893" ;;
    4)
      if [ ! -d "${DEST}/dropbox-893/.git" ]; then
        echo "  video-convert-893 needs dropbox-893."
        echo "  Finished MP4s open from the Dropbox file list. Choose 1 first."
      else
        write_addon "video-convert-893"
      fi
      ;;
    5)
      echo ""
      echo "  Site folder: ${DEST}"
      echo "  Done."
      exit 0
      ;;
    *)
      echo "  Choose 1, 2, 3, 4, or 5."
      ;;
  esac
done
