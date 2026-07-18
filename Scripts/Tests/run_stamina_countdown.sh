#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

cd "$PROJECT_ROOT"
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/StaminaCountdownTest.tscn
