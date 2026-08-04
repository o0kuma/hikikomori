#!/usr/bin/env bash
# N4-W7 — minimal live smoke for the web edge (no browser automation).
# Usage: ./scripts/e2e_web_smoke.sh [BASE_URL]
set -euo pipefail
BASE="${1:-https://msn.iykyka.com}"

echo "==> GET $BASE/health"
curl -fsS "$BASE/health"
echo

echo "==> GET $BASE/demo"
curl -fsS "$BASE/demo" | head -c 400
echo

echo "==> GET $BASE/manifest.json (PWA)"
curl -fsS "$BASE/manifest.json" | head -c 300
echo

echo "==> POST /auth/login DEMO without display_name (expect 400)"
code=$(curl -sS -o /tmp/ykavu_login.json -w '%{http_code}' \
  -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"invite_code":"DEMO-YKAVU"}')
echo "HTTP $code $(head -c 120 /tmp/ykavu_login.json)"
test "$code" = "400"

echo "OK web edge smoke ($BASE)"
