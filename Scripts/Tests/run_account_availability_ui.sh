#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
TEST_PORT="${CCR_ACCOUNT_TEST_PORT:-18767}"

CCR_ACCOUNT_TEST_PORT="$TEST_PORT" node "$PROJECT_ROOT/Scripts/Tests/mock_account_availability_server.mjs" >/tmp/ccr-account-availability-mock.log 2>&1 &
MOCK_PID=$!
cleanup() {
  kill "$MOCK_PID" 2>/dev/null || true
  wait "$MOCK_PID" 2>/dev/null || true
}
trap cleanup EXIT

for _attempt in {1..30}; do
  if curl -sS -X POST "http://127.0.0.1:${TEST_PORT}/api/auth/availability" -H 'Content-Type: application/json' -d '{"username":"probe"}' >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

set +e
OUTPUT="$(CCR_API_BASE_URL="http://127.0.0.1:${TEST_PORT}/api" "$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/AccountAvailabilityUITest.tscn 2>&1)"
STATUS=$?
set -e
printf '%s\n' "$OUTPUT"
if [[ $STATUS -ne 0 ]]; then
  exit $STATUS
fi
printf '%s\n' "$OUTPUT" | grep -q "ACCOUNT_AVAILABILITY_UI ok"
