#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

set +e
OUTPUT="$("$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/LoadingBackgroundTest.tscn 2>&1)"
STATUS=$?
set -e
printf '%s\n' "$OUTPUT"
if [[ $STATUS -ne 0 ]]; then
  exit $STATUS
fi
printf '%s\n' "$OUTPUT" | grep -q "LOADING_BACKGROUND ok"

set +e
OUTPUT="$("$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/BackgroundVisualProbe.tscn 2>&1)"
STATUS=$?
set -e
printf '%s\n' "$OUTPUT"
if [[ $STATUS -ne 0 ]]; then
  exit $STATUS
fi
printf '%s\n' "$OUTPUT" | grep -q "BACKGROUND_VISUAL_PROBE ok"
