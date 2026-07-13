#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CCR_DRAW_CONTINUOUS_PORT:-43112}"
MOCK_LOG="$(mktemp -t ccr-draw-continuous-mock.XXXXXX.log)"

cleanup() {
	if [[ -n "${MOCK_PID:-}" ]]; then
		kill "$MOCK_PID" >/dev/null 2>&1 || true
		wait "$MOCK_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$MOCK_LOG"
}
trap cleanup EXIT

CCR_DRAW_CONTINUOUS_PORT="$PORT" node >"$MOCK_LOG" 2>&1 <<'NODE' &
const http = require("http");
const port = Number(process.env.CCR_DRAW_CONTINUOUS_PORT || 43112);
let prepareCount = 0;

function sendJson(res, status, body) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}
function sendSuccess(res, body) {
  sendJson(res, 200, { success: true, data: body });
}
function makeDeck(deckId) {
  return {
    deck_def_id: deckId,
    deck_name: `连续抽卡组${deckId}`,
    series_name: "连续抽卡测试",
    cards: Array.from({ length: 5 }, (_, index) => ({
      card_def_id: deckId * 100 + index + 1,
      number: index + 1,
      name: `测试子卡${index + 1}`,
      description: "连续抽卡测试。",
      image_url: "",
    })),
  };
}
function dateKey() {
  return new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Shanghai",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}
function makeRoll(index) {
  const deckRoll = index === 1 ? 0.1 : 0.9;
  return {
    key_stale: false,
    roll_id: `00000000-0000-4000-8000-00000000000${index}`,
    signature: `signature-${index}`,
    random_matrix: Array.from({ length: 16 }, () => [deckRoll, 0.01, 0.01]),
    draw_key: {
      date_key: dateKey(),
      version: 1,
      decks: [makeDeck(1), makeDeck(2)],
      number_probabilities: { "1": 1, "2": 0, "3": 0, "4": 0, "5": 0 },
      color_probabilities: { white: 1, green: 0, blue: 0, purple: 0, orange: 0, black: 0 },
    },
    expires_at: "9999-12-31T23:59:59.999Z",
  };
}
function confirmedCards(index) {
  const deckId = index === 1 ? 1 : 2;
  return Array.from({ length: 8 }, (_, slotIndex) => ({
    slot_index: slotIndex,
    card_def_id: deckId * 100 + 1,
    color: "white",
    card_def: {
      id: deckId * 100 + 1,
      number: 1,
      name: "测试子卡1",
      deck_name: `连续抽卡组${deckId}`,
      series_name: "连续抽卡测试",
      description: "连续抽卡测试。",
      image_url: "",
    },
  }));
}

const server = http.createServer((req, res) => {
  if (req.method === "GET" && req.url === "/__health") {
    sendJson(res, 200, { ok: true });
    return;
  }
  if (req.method === "POST" && req.url === "/api/game/refresh-pool/prepare") {
    prepareCount += 1;
    if (prepareCount > 1) {
      sendJson(res, 500, { success: false, error: "continuous draw performed an extra prepare" });
      return;
    }
    setTimeout(() => sendSuccess(res, makeRoll(1)), 30);
    return;
  }
  if (req.method === "POST" && req.url === "/api/game/refresh-pool/confirm") {
    let raw = "";
    req.on("data", (chunk) => { raw += chunk; });
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      const index = String(body.roll_id || "").endsWith("2") ? 2 : 1;
      setTimeout(() => sendSuccess(res, {
        roll_id: body.roll_id,
        confirmed: true,
        cards: confirmedCards(index),
        profile: {
          id: 1,
          username: "continuous-test",
          level: 1,
          exp: 0,
          gold: 1000,
          gems: index === 1 ? 45 : 40,
          combatPower: 0,
          freeRefreshCount: 1,
          newbieFreeRefreshCount: 0,
          lastFreeRefreshTime: new Date().toISOString(),
        },
        next_roll: makeRoll(index + 1),
      }), index === 1 ? 220 : 20);
    });
    return;
  }
  sendJson(res, 404, { success: false, error: "not found" });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`draw continuous mock listening on ${port}`);
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

CCR_DRAW_CONTINUOUS_API_BASE="http://127.0.0.1:${PORT}/api" \
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/DrawContinuousPerfTest.tscn
