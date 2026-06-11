#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CCR_DRAW_LEGACY_PORT:-43108}"
MOCK_LOG="$(mktemp -t ccr-draw-legacy-mock.XXXXXX.log)"

cleanup() {
	if [[ -n "${MOCK_PID:-}" ]]; then
		kill "$MOCK_PID" >/dev/null 2>&1 || true
		wait "$MOCK_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$MOCK_LOG"
}
trap cleanup EXIT

CCR_DRAW_LEGACY_PORT="$PORT" node >"$MOCK_LOG" 2>&1 <<'NODE' &
const http = require("http");

const port = Number(process.env.CCR_DRAW_LEGACY_PORT || 43108);

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function sendSuccess(res, body) {
  sendJson(res, 200, { success: true, data: body });
}

function cardSlot(index) {
  const number = (index % 5) + 1;
  const cardDefId = 100 + number;
  return {
    slot_index: index,
    card_def_id: cardDefId,
    color: "white",
    card_def: {
      id: cardDefId,
      number,
      name: `回退测试子卡${number}`,
      deck_name: "旧接口回退测试",
      series_name: "测试系列",
      description: "用于验证抽卡旧接口回退。",
      image_url: "",
    },
  };
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/__health") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.url === "/api/game/draw-key" || req.url === "/api/game/refresh-pool/prepare") {
    sendJson(res, 404, { error: "not found" });
    return;
  }

  if (req.method === "POST" && req.url === "/api/game/sync-layout") {
    sendSuccess(res, { synced: true });
    return;
  }

  if (req.method === "POST" && req.url === "/api/game/refresh-pool") {
    sendSuccess(res, Array.from({ length: 8 }, (_, index) => cardSlot(index)));
    return;
  }

  if (req.method === "GET" && req.url === "/api/user/profile") {
    sendSuccess(res, {
      id: 1,
      username: "legacy-fallback-test",
      level: 1,
      exp: 0,
      gold: 990,
      gems: 50,
      combatPower: 0,
      freeRefreshCount: 1,
      newbieFreeRefreshCount: 0,
      lastFreeRefreshTime: new Date().toISOString(),
    });
    return;
  }

  sendJson(res, 404, { error: "not found" });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`draw legacy mock listening on ${port}`);
});
NODE
MOCK_PID=$!

for _attempt in {1..40}; do
	if curl -fsS "http://127.0.0.1:${PORT}/__health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.1
done

if ! curl -fsS "http://127.0.0.1:${PORT}/__health" >/dev/null 2>&1; then
	echo "Mock API failed to start. Log:" >&2
	cat "$MOCK_LOG" >&2
	exit 1
fi

CCR_DRAW_LEGACY_API_BASE="http://127.0.0.1:${PORT}/api" \
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/DrawLegacyFallbackTest.tscn
