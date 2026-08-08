#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROBE_DIR="$(mktemp -d /tmp/ccr-exported-audio.XXXXXX)"
trap 'rm -r "$PROBE_DIR"' EXIT

"$GODOT_BIN" --quiet --headless --path "$PROJECT_ROOT" --export-pack Windows "$PROBE_DIR/CCR_Windows.pck"

set +e
OUTPUT="$("$GODOT_BIN" --headless --main-pack "$PROBE_DIR/CCR_Windows.pck" --script "$PROJECT_ROOT/Scripts/Tests/ExportedAudioResourceProbe.gd" 2>&1)"
STATUS=$?
set -e
printf '%s\n' "$OUTPUT"
if [[ $STATUS -ne 0 ]]; then
	exit $STATUS
fi
printf '%s\n' "$OUTPUT" | grep -q "EXPORTED_AUDIO_RESOURCES ok"
