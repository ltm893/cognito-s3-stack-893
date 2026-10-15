#!/bin/bash
# scripts/create-user.test.sh
# Answers create-user.sh against a fake AWS CLI. Does not call AWS.

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
if [[ "$*" == *get-caller-identity* ]]; then
  exit 0
fi
if [[ "$*" == *admin-create-user* ]]; then
  if [ -n "${CREATE_EXISTS:-}" ]; then
    echo "An error occurred (UsernameExistsException) when calling the AdminCreateUser operation: User account already exists" >&2
    exit 254
  fi
  exit 0
fi
if [[ "$*" == *admin-set-user-password* ]]; then
  exit 0
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/aws"

mkdir -p "${TMP}/site/cognito-s3-stack-893/base/bin" "${TMP}/site/dropbox-893"
cat > "${TMP}/site/cognito-s3-stack-893/base/bin/config.ts" <<'EOF'
export const config = {
  id: "abc-site",
  awsRegion: "us-east-1",
};
EOF
cat > "${TMP}/site/dropbox-893/dropbox_outputs.json" <<'EOF'
{ "auth": { "user_pool_id": "us-east-1_POOL" } }
EOF

run_create() {
  SITE_CONFIG_FILE="${TMP}/site/cognito-s3-stack-893/base/bin/config.ts" \
  SITE_PARENT="${TMP}/site" \
  PATH="${FAKE_BIN}:$PATH" \
  "${ROOT}/scripts/create-user.sh"
}

cat > "${TMP}/live-config.ts" <<'EOF'
export const config = { id: "apps-893", awsRegion: "us-east-1" };
EOF
: > "$AWS_LOG"
if SITE_CONFIG_FILE="${TMP}/live-config.ts" PATH="${FAKE_BIN}:$PATH" "${ROOT}/scripts/create-user.sh" >/dev/null 2>&1; then
  fail "create-user ran for the live id"
fi
if [ -s "$AWS_LOG" ]; then
  fail "live id called AWS"
fi

: > "$AWS_LOG"
output="$(printf 'person@example.com\nshort\nPermPass1!\ny\n' | run_create)"
grep -q 'admin-create-user' "$AWS_LOG" || fail "user was not created"
grep -q 'admin-set-user-password' "$AWS_LOG" || fail "password was not set"
grep -q 'us-east-1_POOL' "$AWS_LOG" || fail "pool id was not used"
grep -q -- '--permanent' "$AWS_LOG" || fail "password was not permanent"
printf '%s\n' "$output" | grep -q 'does not meet the pool policy' || fail "weak password was accepted"
if grep -q 'short' "$AWS_LOG"; then
  fail "weak password was sent to AWS"
fi

: > "$AWS_LOG"
CREATE_EXISTS=1 output="$(printf 'person@example.com\nPermPass1!\ny\n' | CREATE_EXISTS=1 run_create)"
grep -q 'admin-set-user-password' "$AWS_LOG" || fail "existing user did not get a password"
printf '%s\n' "$output" | grep -q 'already exists' || fail "existing user was not reported"

echo "create-user checks passed"
