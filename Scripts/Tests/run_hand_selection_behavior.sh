#!/bin/sh
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

"$GODOT_BIN" --headless --path "$PROJECT_ROOT" "res://Scenes/Tests/HandSelectionBehaviorTest.tscn"
