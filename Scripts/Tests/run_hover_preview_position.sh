#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://Scenes/Tests/HoverPreviewPositionTest.tscn
