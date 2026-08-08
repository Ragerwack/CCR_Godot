#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

set +e
OUTPUT="$("$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/CardLocaleRefreshTest.tscn 2>&1)"
STATUS=$?
set -e
printf '%s\n' "$OUTPUT"
if [[ $STATUS -ne 0 ]]; then
	exit $STATUS
fi
printf '%s\n' "$OUTPUT" | grep -q "CARD_LOCALE_REFRESH ok"
