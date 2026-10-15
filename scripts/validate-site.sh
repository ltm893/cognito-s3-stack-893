#!/bin/bash
# scripts/validate-site.sh
# Report the CloudFormation stacks and retained resources for the id in
# base/bin/config.ts. Does not change AWS. Exits 1 when a stack is failed
# or rolling back. Refuses the live site ids.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=site-aws.lib.sh
source "${SCRIPT_DIR}/site-aws.lib.sh"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║            Validate site AWS resources       ║"
echo "╚══════════════════════════════════════════════╝"

load_site
if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  An AWS administrator account is required, with keys installed."
  echo "  Run aws configure, then run this again."
  exit 1
fi

set +e
report_site
failed=$?
set -e
if [ "$failed" -ne 0 ]; then
  echo "  A stack is failed or rolling back."
  exit 1
fi
echo "  CDKToolkit is the account bootstrap. This report does not include it."
echo ""
