#!/bin/bash
# Writes workflows into a temporary family folder. Does not touch the real repos.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/scripts/setup-workflows.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

for repo in cognito-s3-stack-893 dropbox-893 calendar-893 mileage-expense-tracker-893 music-player-893 web-app-893; do
  mkdir -p "${TMP}/${repo}"
done
mkdir -p "${TMP}/web-app-893/.github/workflows"
printf 'name: keep\n' > "${TMP}/web-app-893/.github/workflows/test.yml"

WORKFLOW_PARENT="$TMP" "$SCRIPT" >"${TMP}/out.txt"

for repo in cognito-s3-stack-893 dropbox-893 calendar-893 mileage-expense-tracker-893 music-player-893; do
  [ -f "${TMP}/${repo}/.github/workflows/test.yml" ] || fail "${repo} workflow was not written"
done
grep -q 'npm test' "${TMP}/dropbox-893/.github/workflows/test.yml" || fail "dropbox workflow does not run npm test"
grep -q 'scripts/new-site.test.sh' "${TMP}/cognito-s3-stack-893/.github/workflows/test.yml" || fail "cognito workflow does not run its shell tests"
grep -q 'run_tests.sh' "${TMP}/music-player-893/.github/workflows/test.yml" || fail "music workflow does not run run_tests.sh"
grep -q 'MileageTracker893Tests' "${TMP}/mileage-expense-tracker-893/.github/workflows/test.yml" || fail "mileage workflow does not name its unit tests"
[ -f "${TMP}/mileage-expense-tracker-893/ios/MileageTracker893/MileageTracker893.xcodeproj/xcshareddata/xcschemes/MileageTracker893.xcscheme" ] || fail "mileage scheme was not written"
grep -q 'name: keep' "${TMP}/web-app-893/.github/workflows/test.yml" || fail "existing web-app workflow was replaced"

WORKFLOW_PARENT="$TMP" "$SCRIPT" >"${TMP}/again.txt"
grep -q 'Workflow already present: dropbox-893' "${TMP}/again.txt" || fail "second run rewrote dropbox"

echo "setup-workflows.sh checks passed"
