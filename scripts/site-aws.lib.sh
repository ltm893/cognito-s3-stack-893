#!/bin/bash
# scripts/site-aws.lib.sh
# Shared lookups for validate-site.sh and destroy-site.sh.
# Names come from base/bin/config.ts. Bash 3.2 safe.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${SITE_CONFIG_FILE:-${REPO_ROOT}/base/bin/config.ts}"

config_field() {
  grep -E "^[[:space:]]+$2:" "$1" | head -1 | sed 's/.*"\([^"]*\)".*/\1/'
}

load_site() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "  base/bin/config.ts not found: $CONFIG_FILE"
    exit 1
  fi
  ID="$(config_field "$CONFIG_FILE" id)"
  AWS_REGION="$(config_field "$CONFIG_FILE" awsRegion)"
  USER_POOL_NAME="$(config_field "$CONFIG_FILE" userPoolName)"
  if [ -z "$ID" ] || [ -z "$AWS_REGION" ]; then
    echo "  Could not read id and awsRegion from $CONFIG_FILE"
    exit 1
  fi
  if [ -z "$USER_POOL_NAME" ]; then
    USER_POOL_NAME="${ID}-app-users"
  fi
  case "$ID" in
    dliv|apps-893|met893|your-id-here|dropbox893|calendar893)
      echo "  '$ID' is a live site id. These scripts will not validate or destroy it."
      exit 1
      ;;
  esac
  case "$USER_POOL_NAME" in
    "${ID}"-*) ;;
    *)
      echo "  userPoolName '$USER_POOL_NAME' does not start with ${ID}-."
      echo "  Refusing to touch a pool outside this site."
      exit 1
      ;;
  esac
}

STACKS_DELETE="VideoConvertStack PdfSearchStack CalendarStack DropboxStack MileageExpenseStack CognitoS3BaseStack"
STACKS_REPORT="CognitoS3BaseStack DropboxStack CalendarStack PdfSearchStack VideoConvertStack MileageExpenseStack"

stack_name() {
  echo "${1}-${ID}"
}

stack_status() {
  local name="$1"
  local status
  status="$(aws cloudformation describe-stacks \
    --stack-name "$name" --region "$AWS_REGION" \
    --query "Stacks[0].StackStatus" --output text 2>/dev/null || true)"
  if [ -z "$status" ] || [ "$status" = "None" ]; then
    echo "ABSENT"
  else
    echo "$status"
  fi
}

stack_is_failed() {
  case "$1" in
    *FAILED*|*ROLLBACK*) return 0 ;;
    *) return 1 ;;
  esac
}

bucket_present() {
  aws s3api head-bucket --bucket "$1" --region "$AWS_REGION" >/dev/null 2>&1
}

table_present() {
  local status
  status="$(aws dynamodb describe-table --table-name "$1" --region "$AWS_REGION" \
    --query "Table.TableStatus" --output text 2>/dev/null || true)"
  [ -n "$status" ] && [ "$status" != "None" ]
}

pool_id() {
  python3 - "$AWS_REGION" "$USER_POOL_NAME" <<'PY'
import json, subprocess, sys
region, name = sys.argv[1], sys.argv[2]
token = None
while True:
    cmd = ["aws", "cognito-idp", "list-user-pools", "--max-results", "60", "--region", region, "--output", "json"]
    if token:
        cmd += ["--next-token", token]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(0)
    data = json.loads(proc.stdout or "{}")
    for pool in data.get("UserPools") or []:
        if pool.get("Name") == name:
            sys.stdout.write(pool.get("Id") or "")
            sys.exit(0)
    token = data.get("NextToken")
    if not token:
        sys.exit(0)
PY
}

api_id() {
  aws apigateway get-rest-apis --region "$AWS_REGION" \
    --query "items[?name=='$1'].id | [0]" --output text 2>/dev/null || true
}

cluster_active() {
  local status
  status="$(aws ecs describe-clusters --clusters "$1" --region "$AWS_REGION" \
    --query "clusters[?status=='ACTIVE'].status | [0]" --output text 2>/dev/null || true)"
  [ "$status" = "ACTIVE" ]
}

log_present() {
  local found
  found="$(aws logs describe-log-groups --log-group-name-prefix "$1" --region "$AWS_REGION" \
    --query "logGroups[?logGroupName=='$1'].logGroupName | [0]" --output text 2>/dev/null || true)"
  [ -n "$found" ] && [ "$found" != "None" ]
}

site_buckets() {
  echo "${ID}-public"
  echo "${ID}-private"
  echo "${ID}-pdf-docs"
  echo "${ID}-ancestry-extracts"
  echo "${ID}-video-ingest"
  echo "${ID}-met-receipts"
}

site_tables() {
  echo "${ID}-calendar"
  echo "${ID}-pdf-search-index"
  echo "${ID}-video-convert-jobs"
  echo "${ID}-met-vehicles"
  echo "${ID}-met-trips"
  echo "${ID}-met-expenses"
}

site_apis() {
  echo "${ID}-dropbox-api"
  echo "${ID}-calendar-api"
  echo "${ID}-pdf-search-api"
  echo "${ID}-video-convert-api"
  echo "${ID}-mileage-expense-api"
}

owned_name() {
  case "$1" in
    "${ID}"-*) return 0 ;;
    "/ecs/${ID}-"*) return 0 ;;
    *) return 1 ;;
  esac
}

report_site() {
  local failed=0
  local stack label status found api pool
  echo ""
  echo "  Site:   $ID"
  echo "  Region: $AWS_REGION"
  echo "  Pool:   $USER_POOL_NAME"
  echo ""
  echo "  Stacks"
  for label in $STACKS_REPORT; do
    stack="$(stack_name "$label")"
    status="$(stack_status "$stack")"
    echo "    ${stack}  ${status}"
    if [ "$status" != "ABSENT" ] && stack_is_failed "$status"; then
      failed=1
    fi
  done
  echo ""
  echo "  Buckets"
  for label in $(site_buckets); do
    if bucket_present "$label"; then echo "    ${label}  present"; else echo "    ${label}  absent"; fi
  done
  echo ""
  echo "  Tables"
  for label in $(site_tables); do
    if table_present "$label"; then echo "    ${label}  present"; else echo "    ${label}  absent"; fi
  done
  echo ""
  echo "  User pool"
  pool="$(pool_id)"
  if [ -n "$pool" ]; then echo "    ${USER_POOL_NAME}  ${pool}"; else echo "    ${USER_POOL_NAME}  absent"; fi
  echo ""
  echo "  APIs"
  for label in $(site_apis); do
    api="$(api_id "$label")"
    if [ -n "$api" ] && [ "$api" != "None" ]; then echo "    ${label}  ${api}"; else echo "    ${label}  absent"; fi
  done
  echo ""
  echo "  Video convert"
  if cluster_active "${ID}-video-convert"; then
    echo "    cluster ${ID}-video-convert  ACTIVE"
  else
    echo "    cluster ${ID}-video-convert  absent"
  fi
  if log_present "/ecs/${ID}-video-convert"; then
    echo "    log /ecs/${ID}-video-convert  present"
  else
    echo "    log /ecs/${ID}-video-convert  absent"
  fi
  echo ""
  return "$failed"
}

delete_stack() {
  local name="$1"
  local status
  status="$(stack_status "$name")"
  if [ "$status" = "ABSENT" ]; then
    echo "  Stack absent: $name"
    return 0
  fi
  echo "  Deleting stack: $name ($status)"
  aws cloudformation delete-stack --stack-name "$name" --region "$AWS_REGION"
  aws cloudformation wait stack-delete-complete --stack-name "$name" --region "$AWS_REGION"
  echo "  Deleted stack: $name"
}

empty_and_delete_bucket() {
  local bucket="$1"
  owned_name "$bucket" || return 0
  if ! bucket_present "$bucket"; then
    echo "  Bucket absent: $bucket"
    return 0
  fi
  echo "  Emptying bucket: $bucket"
  python3 - "$bucket" "$AWS_REGION" <<'PY'
import json, subprocess, sys
bucket, region = sys.argv[1], sys.argv[2]

def aws(*args):
    return subprocess.run(["aws", *args], check=True, capture_output=True, text=True)

while True:
    proc = aws("s3api", "list-object-versions", "--bucket", bucket, "--region", region, "--output", "json")
    data = json.loads(proc.stdout or "{}")
    objs = []
    for key in ("Versions", "DeleteMarkers"):
        for item in data.get(key) or []:
            objs.append({"Key": item["Key"], "VersionId": item["VersionId"]})
    if not objs:
        break
    for start in range(0, len(objs), 1000):
        payload = json.dumps({"Objects": objs[start:start + 1000], "Quiet": True})
        aws("s3api", "delete-objects", "--bucket", bucket, "--delete", payload, "--region", region)
    if not data.get("IsTruncated"):
        continue
PY
  aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION"
  echo "  Deleted bucket: $bucket"
}

delete_table() {
  local name="$1"
  owned_name "$name" || return 0
  if ! table_present "$name"; then
    echo "  Table absent: $name"
    return 0
  fi
  echo "  Deleting table: $name"
  aws dynamodb delete-table --table-name "$name" --region "$AWS_REGION" >/dev/null
  echo "  Deleted table: $name"
}

delete_pool() {
  local pool
  pool="$(pool_id)"
  if [ -z "$pool" ]; then
    echo "  User pool absent: $USER_POOL_NAME"
    return 0
  fi
  echo "  Deleting user pool: $USER_POOL_NAME ($pool)"
  aws cognito-idp delete-user-pool --user-pool-id "$pool" --region "$AWS_REGION"
  echo "  Deleted user pool: $USER_POOL_NAME"
}

delete_api() {
  local name="$1"
  local found
  owned_name "$name" || return 0
  found="$(api_id "$name")"
  if [ -z "$found" ] || [ "$found" = "None" ]; then
    echo "  API absent: $name"
    return 0
  fi
  echo "  Deleting API: $name ($found)"
  aws apigateway delete-rest-api --rest-api-id "$found" --region "$AWS_REGION"
  echo "  Deleted API: $name"
}

delete_cluster() {
  local name="${ID}-video-convert"
  if ! cluster_active "$name"; then
    echo "  Cluster absent: $name"
    return 0
  fi
  echo "  Deleting cluster: $name"
  aws ecs delete-cluster --cluster "$name" --region "$AWS_REGION" >/dev/null
  echo "  Deleted cluster: $name"
}

delete_log() {
  local name="/ecs/${ID}-video-convert"
  if ! log_present "$name"; then
    echo "  Log group absent: $name"
    return 0
  fi
  echo "  Deleting log group: $name"
  aws logs delete-log-group --log-group-name "$name" --region "$AWS_REGION"
  echo "  Deleted log group: $name"
}
