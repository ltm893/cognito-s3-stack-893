#!/bin/bash
# scripts/setup-amplify.test.sh
# Answers setup-amplify.sh against a fake AWS CLI. Does not call AWS or GitHub.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
AWS_LOG="${TMP}/aws.log"
export AWS_LOG

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

FAKE_BIN="${TMP}/bin"
mkdir -p "$FAKE_BIN"
cat > "${FAKE_BIN}/aws" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$AWS_LOG"
prev=""
for arg in "$@"; do
  if [ "$prev" = "--cli-input-json" ]; then
    file="${arg#file://}"
    echo "JSON $(cat "$file")" >> "$AWS_LOG"
  fi
  prev="$arg"
done
if [[ "$*" == *get-caller-identity* ]]; then
  exit 0
fi
if [[ "$*" == *list-apps* ]]; then
  echo '{"apps":[]}'
  exit 0
fi
if [[ "$*" == *create-app* ]]; then
  echo '{"app":{"appId":"d123abc"}}'
  exit 0
fi
if [[ "$*" == *get-branch* ]]; then
  exit 254
fi
if [[ "$*" == *create-branch* ]]; then
  echo '{"branch":{"branchName":"dev"}}'
  exit 0
fi
if [[ "$*" == *start-job* ]]; then
  echo '{"jobSummary":{"jobId":"1"}}'
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/aws"

mkdir -p "${TMP}/site/cognito-s3-stack-893/base/bin" \
  "${TMP}/site/dropbox-893" "${TMP}/site/calendar-893" \
  "${TMP}/site/pdf-search-893" "${TMP}/site/video-convert-893"
cat > "${TMP}/site/cognito-s3-stack-893/base/bin/config.ts" <<'EOF'
export const config = {
  id: "abc-site",
  awsRegion: "us-east-1",
  userPoolName: "abc-site-app-users",
};
EOF
cat > "${TMP}/site/dropbox-893/dropbox_outputs.json" <<'EOF'
{
  "aws_region": "us-east-1",
  "auth": { "user_pool_id": "us-east-1_POOL", "user_pool_client_id": "dropbox-client-id" },
  "api": { "base_url": "https://dropbox.example.com/prod/" }
}
EOF
cat > "${TMP}/site/calendar-893/calendar_outputs.json" <<'EOF'
{ "api": { "base_url": "https://calendar.example.com/prod/" } }
EOF
cat > "${TMP}/site/pdf-search-893/pdf_search_outputs.json" <<'EOF'
{ "api": { "base_url": "https://pdf.example.com/prod/" } }
EOF
cat > "${TMP}/site/video-convert-893/video_convert_outputs.json" <<'EOF'
{ "api": { "base_url": "https://video.example.com/prod/" } }
EOF
echo '{"auth":{"user_pool_client_id":"base-client-id"}}' > "${TMP}/site/cognito-s3-stack-893/base_outputs.json"

run_setup() {
  SITE_CONFIG_FILE="${TMP}/site/cognito-s3-stack-893/base/bin/config.ts" \
  SITE_PARENT="${TMP}/site" \
  PATH="${FAKE_BIN}:$PATH" \
  "${ROOT}/scripts/setup-amplify.sh"
}

cat > "${TMP}/live-config.ts" <<'EOF'
export const config = { id: "apps-893", awsRegion: "us-east-1" };
EOF
: > "$AWS_LOG"
if SITE_CONFIG_FILE="${TMP}/live-config.ts" PATH="${FAKE_BIN}:$PATH" "${ROOT}/scripts/setup-amplify.sh" >/dev/null 2>&1; then
  fail "setup ran for the live id"
fi
if [ -s "$AWS_LOG" ]; then
  fail "live id called AWS"
fi

: > "$AWS_LOG"
rm -f "${TMP}/site/dropbox-893/dropbox_outputs.json"
if printf '\n' | run_setup >/dev/null 2>&1; then
  fail "setup ran without Dropbox outputs"
fi
if grep -q create-app "$AWS_LOG"; then
  fail "missing Dropbox outputs created an app"
fi
cat > "${TMP}/site/dropbox-893/dropbox_outputs.json" <<'EOF'
{
  "aws_region": "us-east-1",
  "auth": { "user_pool_id": "us-east-1_POOL", "user_pool_client_id": "dropbox-client-id" },
  "api": { "base_url": "https://dropbox.example.com/prod/" }
}
EOF

: > "$AWS_LOG"
if printf '\n\n\n\nhttps://github.com/ltm893/dliv-web.git\n' | run_setup >/dev/null 2>&1; then
  fail "dliv-web was accepted as the website repo"
fi
if grep -q create-app "$AWS_LOG"; then
  fail "dliv-web created an app"
fi

: > "$AWS_LOG"
output="$(printf '\n\n\n\n\n\nghp_test\ny\nn\n' | run_setup)"
grep -q 'dropbox-client-id' "$AWS_LOG" || fail "Dropbox client id was not sent"
if grep -q 'base-client-id' "$AWS_LOG"; then
  fail "base client id was sent"
fi
grep -q 'https://calendar.example.com/prod/' "$AWS_LOG" || fail "calendar URL was not sent"
grep -q 'https://video.example.com/prod/' "$AWS_LOG" || fail "video URL was not sent"
grep -q 'start-job' "$AWS_LOG" || fail "token path did not start the build"
printf '%s\n' "$output" | grep -q 'https://us-east-1.console.aws.amazon.com/amplify/apps/d123abc' || fail "console URL missing"
printf '%s\n' "$output" | grep -q 'https://dev.d123abc.amplifyapp.com' || fail "site URL missing"

: > "$AWS_LOG"
output="$(printf '\n\n\n\n\n\n\ny\nn\n' | run_setup)"
if grep -q 'accessToken' "$AWS_LOG"; then
  fail "empty token was sent to AWS"
fi
if grep -q 'start-job' "$AWS_LOG"; then
  fail "console path started a build before GitHub was connected"
fi
printf '%s\n' "$output" | grep -q 'Connect branch' || fail "console steps missing"
if grep -q 'repository' "$AWS_LOG"; then
  fail "console path sent a repository"
fi

echo "setup-amplify checks passed"
