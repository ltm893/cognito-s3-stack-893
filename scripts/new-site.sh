#!/bin/bash
# scripts/new-site.sh
# Clone the fork trial repos and write config.ts for a new id.
# Does not deploy AWS. Does not touch an existing dliv checkout.
#
# Usage:
#   ./scripts/new-site.sh <id> [parent-dir]
#
# Example:
#   ./scripts/new-site.sh acme
#   ./scripts/new-site.sh acme ~/Dev/projects

set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 <id> [parent-dir]"
  echo "  id: lowercase letters, numbers, hyphens. Not dliv, apps-893, or met893."
  exit 1
fi

ID="$1"
PARENT="${2:-$HOME/Dev/projects}"
DEST="${PARENT}/${ID}"

if ! [[ "$ID" =~ ^[a-z0-9]([a-z0-9-]{0,53}[a-z0-9])?$ ]]; then
  echo "  id must be 1–55 characters: lowercase letters, numbers, and hyphens, and must not start or end with a hyphen."
  exit 1
fi

case "$ID" in
  dliv|apps-893|met893|your-id-here)
    echo "  id '$ID' is reserved. Pick another."
    exit 1
    ;;
esac

if [ -e "$DEST" ]; then
  echo "  $DEST already exists. Pick another id or another parent directory."
  exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            New site — clone and config       ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  ID:         $ID"
echo "  Directory:  $DEST"
echo "  Branch:     dev"
echo ""
echo "  Clones:"
echo "    cognito-s3-stack-893"
echo "    dropbox-893"
echo "    calendar-893"
echo "    web-app-893"
echo ""
echo "  config.ts:"
echo "    base id ${ID}, pool ${ID}-app-users"
echo "    add-ons read that id; they do not set their own"
echo "    buckets ${ID}-public and ${ID}-private"
echo "    calendar table defaults to ${ID}-calendar, createTable defaults to true"
echo ""
echo "  From email Cognito will use for invites."
echo "  SES must accept this address or invite mail will not send."
read -r -p "  From email [noreply@yourdomain.com]: " FROM_EMAIL
FROM_EMAIL="${FROM_EMAIL:-noreply@yourdomain.com}"
echo ""
echo "  This writes gitignored config files. It does not deploy AWS and does not clone dliv-web."
read -r -p "  Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "  Cancelled."
  exit 0
fi

mkdir -p "$DEST"
cd "$DEST"

clone() {
  local repo="$1"
  echo ""
  echo "  Cloning $repo..."
  git clone --branch dev "https://github.com/ltm893/${repo}.git"
}

clone cognito-s3-stack-893
clone dropbox-893
clone calendar-893
clone web-app-893

cp cognito-s3-stack-893/base/bin/config.example.ts cognito-s3-stack-893/base/bin/config.ts
cp dropbox-893/backend/bin/config.example.ts dropbox-893/backend/bin/config.ts
cp calendar-893/backend/bin/config.example.ts calendar-893/backend/bin/config.ts

export NEW_SITE_ID="$ID"
export NEW_SITE_EMAIL="$FROM_EMAIL"
python3 - <<'PY'
import os
from pathlib import Path

site_id = os.environ["NEW_SITE_ID"]
email = os.environ["NEW_SITE_EMAIL"]
root = Path(".")
files = [
    root / "cognito-s3-stack-893/base/bin/config.ts",
    root / "dropbox-893/backend/bin/config.ts",
    root / "calendar-893/backend/bin/config.ts",
]
for path in files:
    text = path.read_text()
    text = text.replace("your-id-here", site_id)
    if path.name == "config.ts" and "fromEmail" in text:
        text = text.replace("noreply@yourdomain.com", email)
    path.write_text(text)
PY

echo ""
echo "  Ready: $DEST"
echo ""
echo "  Next:"
echo "    1. cd ${DEST}/cognito-s3-stack-893/base && ./scripts/deploy.sh"
echo "    2. Copy auth.user_pool_id from base_outputs.json into both remaining config.ts files."
echo "    3. cd ${DEST}/dropbox-893/backend && ./scripts/deploy.sh"
echo "    4. cd ${DEST}/calendar-893/backend && ./scripts/deploy.sh"
echo "       After that deploy succeeds, set createTable to false."
echo "    5. Create an Amplify app on ${DEST}/web-app-893."
echo "       USER_POOL_CLIENT_ID comes from dropbox_outputs.json, not base_outputs.json."
echo ""
