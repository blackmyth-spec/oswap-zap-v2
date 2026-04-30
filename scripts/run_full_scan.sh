#!/bin/bash
set -e

# ============================================================
# run_full_scan.sh
# Login to DummyJSON API, extract accessToken, then run ZAP
# scan against all endpoints defined in the Postman collection.
# ============================================================

# Use LOGIN_URL from env, or construct from TARGET_URL
LOGIN_URL="${LOGIN_URL:-${TARGET_URL%/}/auth/login}"

echo "[+] Logging in to ${LOGIN_URL}..."

RAW_RESPONSE=$(curl -sk --compressed -X POST "$LOGIN_URL" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")

echo "[DEBUG] Raw response:"
echo "$RAW_RESPONSE"

# Extract accessToken from DummyJSON login response
TOKEN=$(echo "$RAW_RESPONSE" | jq -r '.accessToken' 2>/dev/null || true)

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  echo "[!] Failed to retrieve accessToken"
  echo "$RAW_RESPONSE"
  exit 1
fi

echo "[+] JWT accessToken acquired"

mkdir -p reports

# Build the ZAP automation plan from the Postman collection endpoints
cat > zap-plan.yaml <<EOF
env:
  contexts:
    - name: DummyJSON
      urls:
        - "${TARGET_URL%/}"
      includePaths:
        - "${TARGET_URL%/}/.*"
  parameters:
    failOnError: false
    progressToStdout: true

jobs:
  # ---- Seed URLs from Postman Collection ----
  - type: requestor
    requests:
      # Login endpoint (POST)
      - url: "${TARGET_URL%/}/auth/login"
        method: POST
        httpVersion: "HTTP/1.1"
        headers:
          - "Content-Type: application/json"
        data: '{"username":"${USERNAME}","password":"${PASSWORD}"}'

      # Get Current User
      - url: "${TARGET_URL%/}/auth/me"
        method: GET

      # Get Products
      - url: "${TARGET_URL%/}/products"
        method: GET

      # Get Cart
      - url: "${TARGET_URL%/}/carts/1"
        method: GET

  # ---- Spider ----
  - type: spider
    parameters:
      context: DummyJSON
      url: "${TARGET_URL%/}"
      maxDuration: 5

  # ---- Active Scan ----
  - type: activeScan
    parameters:
      context: DummyJSON

  # ---- Reports ----
  - type: report
    parameters:
      template: traditional-html
      reportDir: /zap/wrk/reports
      reportFile: zap_full_report.html

  - type: report
    parameters:
      template: traditional-json
      reportDir: /zap/wrk/reports
      reportFile: zap_full_report.json
EOF

echo "[+] ZAP plan generated with endpoints from Postman collection"

# Ensure the reports directory is writable by the ZAP container user (uid 1000)
chmod -R 777 reports 2>/dev/null || true

# Run ZAP with the replacer rule to inject the Bearer token into all requests
docker run --rm \
  -e JAVA_OPTS="-Djava.util.prefs.userRoot=/tmp/.java -Djava.util.prefs.systemRoot=/tmp/.java" \
  -v "$(pwd)/reports":/zap/wrk/reports:rw \
  -v "$(pwd)/zap-plan.yaml":/zap/wrk/zap-plan.yaml:ro \
  ghcr.io/zaproxy/zaproxy:stable \
  zap.sh -cmd -dir /tmp -autorun /zap/wrk/zap-plan.yaml \
  "-config" "replacer.full_list(0).description=auth" \
  "-config" "replacer.full_list(0).enabled=true" \
  "-config" "replacer.full_list(0).matchtype=REQ_HEADER" \
  "-config" "replacer.full_list(0).matchstr=Authorization" \
  "-config" "replacer.full_list(0).replacement=Bearer $TOKEN"

# Post-fix permission (safe)
chmod -R 775 reports || true

echo "[+] Full scan complete"