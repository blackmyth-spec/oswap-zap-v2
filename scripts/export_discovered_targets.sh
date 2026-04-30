#!/usr/bin/env bash

set -Eeuo pipefail

REPORT_DIR="${1:-$(pwd)/reports}"
OUTPUT_FILE="${REPORT_DIR}/zap_discovered_targets.txt"
JSON_EXPORT="${REPORT_DIR}/zap_discovered_targets.json"

log() {
  echo "[$(date '+%F %T')] [EXPORT] $*"
}

fail() {
  echo "[$(date '+%F %T')] [ERROR] $*" >&2
  exit 1
}

[[ -f "${REPORT_DIR}/zap_full_report.json" ]] || fail "Missing zap_full_report.json"

log "Extracting discovered URLs and APIs..."

jq '
[
  .site[]?.alerts[]?.instances[]?.uri
] | unique
' "${REPORT_DIR}/zap_full_report.json" > "${JSON_EXPORT}"

jq -r '.[]' "${JSON_EXPORT}" > "${OUTPUT_FILE}"

COUNT=$(wc -l < "${OUTPUT_FILE}" || echo 0)

log "Export completed"
log "Found ${COUNT} unique targets"

echo "Saved:"
echo " - ${OUTPUT_FILE}"
echo " - ${JSON_EXPORT}"