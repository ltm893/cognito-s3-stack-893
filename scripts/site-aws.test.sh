#!/bin/bash
# scripts/site-aws.test.sh
# Runs validate-site.sh and destroy-site.sh against a fake aws. No AWS account.

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
if [[ "$*" == *list-user-pools* ]]; then
  echo '{"UserPools":[{"Name":"abc-site-app-users","Id":"us-east-1_TESTPOOL"}]}'
  exit 0
fi
if [[ "$*" == *list-object-versions* ]]; then
  echo '{"Versions":[],"DeleteMarkers":[]}'
  exit 0
fi
if [[ "$*" == *describe-stacks* && "$*" == *CognitoS3BaseStack-abc-site* ]]; then
  echo "CREATE_COMPLETE"
  exit 0
fi
if [[ "$*" == *describe-stacks* && "$*" == *VideoConvertStack-abc-site* ]]; then
  echo "CREATE_COMPLETE"
  exit 0
fi
if [[ "$*" == *describe-stacks* ]]; then
  exit 254
fi
exit 0
EOF
chmod +x "${FAKE_BIN}/aws"

write_config() {
  local id="$1"
  cat > "${TMP}/config.ts" <<EOF
export const config = {
  id: "${id}",
  awsRegion: "us-east-1",
  userPoolName: "${id}-app-users",
};
EOF
}

run_validate() {
  SITE_CONFIG_FILE="${TMP}/config.ts" PATH="${FAKE_BIN}:$PATH" "${ROOT}/scripts/validate-site.sh"
}

run_destroy() {
  SITE_CONFIG_FILE="${TMP}/config.ts" PATH="${FAKE_BIN}:$PATH" "${ROOT}/scripts/destroy-site.sh"
}

write_config "apps-893"
: > "$AWS_LOG"
if run_validate >/dev/null 2>&1; then
  fail "validate ran for the live id"
fi
if [ -s "$AWS_LOG" ]; then
  fail "live id called AWS"
fi

write_config "abc-site"
: > "$AWS_LOG"
output="$(run_validate)"
printf '%s\n' "$output" | grep -q "CognitoS3BaseStack-abc-site  CREATE_COMPLETE" || fail "base stack was not reported"
printf '%s\n' "$output" | grep -q "DropboxStack-abc-site  ABSENT" || fail "missing stack was not absent"
printf '%s\n' "$output" | grep -q "abc-site-private  present" || fail "bucket was not reported"
printf '%s\n' "$output" | grep -q "CDKToolkit" || fail "bootstrap note missing"

: > "$AWS_LOG"
if printf 'nope\n' | run_destroy >/dev/null 2>&1; then
  fail "wrong confirmation was accepted"
fi
if grep -q "delete-stack" "$AWS_LOG"; then
  fail "wrong confirmation deleted a stack"
fi

: > "$AWS_LOG"
printf 'abc-site\n' | run_destroy >/dev/null
video_line="$(grep -n 'delete-stack --stack-name VideoConvertStack-abc-site' "$AWS_LOG" | head -1 | cut -d: -f1 || true)"
base_line="$(grep -n 'delete-stack --stack-name CognitoS3BaseStack-abc-site' "$AWS_LOG" | head -1 | cut -d: -f1 || true)"
if [ -z "$video_line" ] || [ -z "$base_line" ] || [ "$video_line" -ge "$base_line" ]; then
  fail "add-on stack was not deleted before the base stack"
fi
grep -q 'delete-bucket --bucket abc-site-private' "$AWS_LOG" || fail "retained bucket was not deleted"
grep -q 'delete-user-pool --user-pool-id us-east-1_TESTPOOL' "$AWS_LOG" || fail "user pool was not deleted"
if grep -q 'CDKToolkit' "$AWS_LOG"; then
  fail "destroy touched CDKToolkit"
fi

echo "site aws checks passed"
