#!/bin/bash
# The reset email is the Cognito verification template. The code placeholder
# stays, and the sentence does not end with a period.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="${ROOT}/base/lib/base-stack.ts"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

grep -F 'emailSubject: "Your DLIV password reset code"' "$FILE" >/dev/null \
  || fail "reset email subject is missing"
grep -F 'emailBody: "Your code is a DLIV password reset code: {####}"' "$FILE" >/dev/null \
  || fail "reset email must include the code placeholder and no trailing period"
grep -F 'Your temporary password is' "$FILE" >/dev/null \
  || fail "invite email was changed"

echo "reset email template checks passed"
