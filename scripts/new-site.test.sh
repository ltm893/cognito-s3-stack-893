#!/bin/bash
# scripts/new-site.test.sh
# Answers new-site.sh prompts in a temporary folder. Does not call AWS or GitHub.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/scripts/new-site.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [ "$got" != "$want" ]; then
    fail "${label}: got '${got}', want '${want}'"
  fi
}

run_site() {
  NEW_SITE_PARENT="$TMP" PATH="$FAKE_BIN:$PATH" "$SCRIPT"
}

FAKE_BIN="${TMP}/bin"
mkdir -p "$FAKE_BIN"
cat > "${FAKE_BIN}/git" <<'EOF'
#!/bin/bash
target="${@: -1}"
mkdir -p "${target}/backend/bin" "${target}/.git"
cat > "${target}/backend/bin/config.example.ts" <<'EXAMPLE'
export const config = {
  awsRegion: "us-east-1",
  userPoolId: "us-east-1_XXXXXXXXX",
  privateBucket: "your-id-here-private",
  publicBucket: "your-id-here-public",
  docsBucket: "your-id-here-private",
};
EXAMPLE
exit 0
EOF
chmod +x "${FAKE_BIN}/git"
cat > "${FAKE_BIN}/aws" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "${FAKE_BIN}/aws"

# A no answer creates no folder.
printf 'not valid\nabc-site\n\nn\n' | run_site >/dev/null
if [ -e "${TMP}/abc-site" ]; then
  fail "cancel created ${TMP}/abc-site"
fi

# An existing base with no outputs asks to deploy. No skips it.
BASE="${TMP}/abc-site/cognito-s3-stack-893"
mkdir -p "${BASE}/base/bin" "${BASE}/base/scripts" "${BASE}/.git"
cat > "${BASE}/base/bin/config.ts" <<'EOF'
export const config = {
  id: "abc-site",
  awsRegion: "us-east-1",
  fromEmail: "noreply@yourdomain.com",
};
EOF
cat > "${BASE}/base/scripts/deploy.sh" <<'EOF'
#!/bin/bash
echo deployed-base > "$(dirname "$0")/deployed-base"
exit 0
EOF
chmod +x "${BASE}/base/scripts/deploy.sh"

printf 'abc-site\nn\n5\n' | run_site >/dev/null
if [ -e "${BASE}/base/scripts/deployed-base" ]; then
  fail "answering n ran the base deploy"
fi

printf 'abc-site\ny\n5\n' | run_site >/dev/null
if [ ! -f "${BASE}/base/scripts/deployed-base" ]; then
  fail "answering y did not run the base deploy"
fi

printf 'abc-site\n4\n5\n' | run_site >/dev/null
if [ -e "${TMP}/abc-site/video-convert-893" ]; then
  fail "video convert ran before dropbox"
fi

# Outputs let the next add-on copy the pool id and ask before its own deploy.
cat > "${BASE}/base_outputs.json" <<'EOF'
{
  "aws_region": "us-east-1",
  "auth": { "user_pool_id": "us-east-1_TESTPOOL" },
  "storage": {
    "public_bucket": "abc-site-public",
    "private_bucket": "abc-site-private"
  }
}
EOF
mkdir -p "${TMP}/abc-site/dropbox-893/backend/scripts"
cat > "${TMP}/abc-site/dropbox-893/backend/scripts/deploy.sh" <<'EOF'
#!/bin/bash
echo deployed-dropbox > "$(dirname "$0")/deployed-dropbox"
exit 0
EOF
chmod +x "${TMP}/abc-site/dropbox-893/backend/scripts/deploy.sh"
rm -rf "${TMP}/abc-site/dropbox-893/.git"

printf 'abc-site\n1\ny\n5\n' | run_site >/dev/null
CONFIG="${TMP}/abc-site/dropbox-893/backend/bin/config.ts"
grep -q 'us-east-1_TESTPOOL' "$CONFIG" || fail "add-on config did not receive the pool id"
if [ ! -f "${TMP}/abc-site/dropbox-893/backend/scripts/deployed-dropbox" ]; then
  fail "answering y did not run the dropbox deploy"
fi

rm -f "${TMP}/abc-site/dropbox-893/backend/scripts/deployed-dropbox"
printf 'abc-site\n1\nn\nn\n5\n' | run_site >/dev/null
if [ -e "${TMP}/abc-site/dropbox-893/backend/scripts/deployed-dropbox" ]; then
  fail "answering n ran the dropbox deploy"
fi

printf 'abc-site\n4\nn\n5\n' | run_site >/dev/null
VIDEO_CONFIG="${TMP}/abc-site/video-convert-893/backend/bin/config.ts"
if [ ! -d "${TMP}/abc-site/video-convert-893/.git" ]; then
  fail "video convert did not run after dropbox"
fi
grep -q 'us-east-1_TESTPOOL' "$VIDEO_CONFIG" || fail "video convert config did not receive the pool id"

cat > "${FAKE_BIN}/docker" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "${FAKE_BIN}/docker"
mkdir -p "${TMP}/abc-site/video-convert-893/backend/scripts"
cat > "${TMP}/abc-site/video-convert-893/backend/scripts/deploy.sh" <<'EOF'
#!/bin/bash
echo deployed-video > "$(dirname "$0")/deployed-video"
exit 0
EOF
chmod +x "${TMP}/abc-site/video-convert-893/backend/scripts/deploy.sh"
printf 'abc-site\n4\nn\ny\n5\n' | run_site >/dev/null
if [ -e "${TMP}/abc-site/video-convert-893/backend/scripts/deployed-video" ]; then
  fail "video convert deploy ran while Docker was down"
fi

cat > "${FAKE_BIN}/aws" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "${FAKE_BIN}/aws"
printf 'abc-site\n1\nn\ny\n5\n' | run_site >/dev/null
if [ -e "${TMP}/abc-site/dropbox-893/backend/scripts/deployed-dropbox" ]; then
  fail "deploy ran without AWS keys"
fi

AWS_LOG="${TMP}/aws.log"
: > "$AWS_LOG"
cat > "${FAKE_BIN}/aws" <<EOF
#!/bin/bash
echo "\$*" >> "${AWS_LOG}"
if [ "\$1" = "s3api" ] && [ "\$2" = "head-bucket" ]; then
  exit 1
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/aws"
printf 'abc-site\n3\ny\n5\n' | run_site >/dev/null 2>&1
PDF_CONFIG="${TMP}/abc-site/pdf-search-893/backend/bin/config.ts"
grep -q 'docsBucket: "abc-site-pdf-docs"' "$PDF_CONFIG" || fail "pdf config did not use the archive bucket"
if grep -q 'docsBucket: "abc-site-private"' "$PDF_CONFIG"; then
  fail "pdf config used the Dropbox private bucket"
fi
grep -q 'create-bucket --bucket abc-site-pdf-docs' "$AWS_LOG" || fail "archive bucket was not created"
grep -q 'put-public-access-block --bucket abc-site-pdf-docs' "$AWS_LOG" || fail "archive bucket was left public"
if grep -q 'create-bucket --bucket abc-site-private' "$AWS_LOG"; then
  fail "Dropbox private bucket was created as the archive bucket"
fi

echo "new-site.sh prompt checks passed"
