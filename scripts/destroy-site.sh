#!/bin/bash
# scripts/destroy-site.sh
# Delete the CloudFormation stacks for the id in base/bin/config.ts, then the
# retained buckets, tables, user pool, APIs, cluster, and log group those
# stacks leave behind. Does not delete CDKToolkit. Refuses the live site ids.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=site-aws.lib.sh
source "${SCRIPT_DIR}/site-aws.lib.sh"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║             Destroy site AWS resources       ║"
echo "╚══════════════════════════════════════════════╝"

load_site
if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "  An AWS administrator account is required, with keys installed."
  echo "  Run aws configure, then run this again."
  exit 1
fi

set +e
report_site
set -e

echo "  This deletes those stacks, then the retained buckets, tables, and user pool."
echo "  Add-on stacks go first. The base stack goes last. CDKToolkit stays."
echo ""
read -r -p "  Type the site id to destroy it: " CONFIRM || exit 1
if [ "$CONFIRM" != "$ID" ]; then
  echo "  Cancelled."
  exit 1
fi

echo ""
for label in $STACKS_DELETE; do
  delete_stack "$(stack_name "$label")"
done

echo ""
echo "  Removing retained resources for ${ID}."
for label in $(site_buckets); do
  empty_and_delete_bucket "$label"
done
for label in $(site_tables); do
  delete_table "$label"
done
for label in $(site_apis); do
  delete_api "$label"
done
delete_cluster
delete_log
delete_pool

echo ""
echo "  Destroy finished for ${ID}. Amplify apps are not removed."
echo ""
