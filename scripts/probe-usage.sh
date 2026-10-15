#!/bin/bash
# Fetches Claude OAuth usage JSON to scripts/usage-sample.json. Never prints the token.
set -euo pipefail
OUT="$(cd "$(dirname "$0")" && pwd)/usage-sample.json"
CREDS="$(security find-generic-password -s "Claude Code-credentials" -w)"
TOKEN="$(printf '%s' "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin)["claudeAiOauth"]["accessToken"])')"
EXP="$(printf '%s' "$CREDS" | python3 -c 'import sys,json; print(json.load(sys.stdin)["claudeAiOauth"].get("expiresAt"))')"
echo "expiresAt: $EXP"
CODE=$(curl -s -o "$OUT" -w '%{http_code}' https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20")
echo "HTTP $CODE -> $OUT"
