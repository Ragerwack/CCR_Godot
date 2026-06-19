#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CCR_DRAW_CONFIRM_RETRY_PORT:-43110}"
MOCK_LOG="$(mktemp -t ccr-draw-confirm-retry.XXXXXX.log)"

cleanup() {
	if [[ -n "${MOCK_PID:-}" ]]; then
		kill "$MOCK_PID" >/dev/null 2>&1 || true
		wait "$MOCK_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$MOCK_LOG"
}
trap cleanup EXIT

CCR_DRAW_CONFIRM_RETRY_PORT="$PORT" node >"$MOCK_LOG" 2>&1 <<'NODE' &
const http = require("http");

const port = Number(process.env.CCR_DRAW_CONFIRM_RETRY_PORT || 43110);
const expectedOperationId = "refresh_pool_confirm:test:weaknet";
const expectedRollId = "00000000-0000-4000-8000-000000000099";
let confirmCount = 0;
let firstOperationId = null;

function readBody(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => {
      body += chunk;
    });
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (_err) {
        resolve({});
      }
    });
  });
}

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

function sendSuccess(res, body) {
  sendJson(res, 200, { success: true, data: body });
}

function confirmedCards() {
  return Array.from({ length: 3 }, (_, index) => ({
    slot_index: index,
    card_def_id: 9900 + index,
    color: "white",
    card_def: {
      id: 9900 + index,
      number: index + 1,
      name: `弱网测试子卡${index + 1}`,
      deck_name: "弱网测试套牌",
      series_name: "弱网测试系列",
      description: "用于验证抽卡确认重试。",
      image_url: "",
    },
  }));
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/__health") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.method === "POST" && req.url === "/api/game/refresh-pool/confirm") {
    const body = await readBody(req);
    confirmCount += 1;

    if (body.operation_id !== expectedOperationId) {
      sendJson(res, 409, { success: false, error: `operation_id mismatch: ${body.operation_id}` });
      return;
    }

    if (body.roll_id !== expectedRollId || body.signature !== "retry-signature") {
      sendJson(res, 400, { success: false, error: "roll mismatch" });
      return;
    }

    if (confirmCount === 1) {
      firstOperationId = body.operation_id;
      sendJson(res, 503, { success: false, error: "temporary gateway" });
      return;
    }

    if (firstOperationId !== body.operation_id) {
      sendJson(res, 409, { success: false, error: "operation_id not reused" });
      return;
    }

    sendSuccess(res, {
      roll_id: expectedRollId,
      confirmed: true,
      cards: confirmedCards(),
      profile: {
        id: 1,
        username: "confirm-retry-test",
        level: 1,
        exp: 0,
        gold: 1000,
        gems: 50,
        combatPower: 0,
        freeRefreshCount: 1,
        newbieFreeRefreshCount: 0,
        lastFreeRefreshTime: new Date().toISOString(),
      },
    });
    return;
  }

  sendJson(res, 404, { error: "not found" });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`draw confirm retry mock listening on ${port}`);
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

CCR_DRAW_CONFIRM_RETRY_API_BASE="http://127.0.0.1:${PORT}/api" \
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/DrawConfirmRetryTest.tscn
