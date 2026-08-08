#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path "$(cd "$(dirname "$0")/../.." && pwd)" --scene res://Scenes/Tests/NavigationResponsiveLayoutTest.tscn
