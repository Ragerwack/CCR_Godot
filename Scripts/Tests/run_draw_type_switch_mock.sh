#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CCR_DRAW_TYPE_SWITCH_PORT:-43109}"
MOCK_LOG="$(mktemp -t ccr-draw-type-switch.XXXXXX.log)"

cleanup() {
	if [[ -n "${MOCK_PID:-}" ]]; then
		kill "$MOCK_PID" >/dev/null 2>&1 || true
		wait "$MOCK_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$MOCK_LOG"
}
trap cleanup EXIT

CCR_DRAW_TYPE_SWITCH_PORT="$PORT" node >"$MOCK_LOG" 2>&1 <<'NODE' &
const http = require("http");

const port = Number(process.env.CCR_DRAW_TYPE_SWITCH_PORT || 43109);
let pending = null;

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

function makeDeck(deckId, deckName) {
  return {
    deck_def_id: deckId,
    deck_name: deckName,
    series_name: "类型切换测试系列",
    cards: Array.from({ length: 5 }, (_, index) => {
      const number = index + 1;
      return {
        card_def_id: deckId * 100 + number,
        number,
        name: `类型切换子卡${number}`,
        description: "用于刷新类型切换验证。",
        image_url: "",
      };
    }),
  };
}

function makeDrawKey() {
  return {
    date_key: "2026-06-11",
    version: 1,
    decks: [makeDeck(1, "类型测试一"), makeDeck(2, "类型测试二")],
    number_probabilities: {
      "1": 0.3,
      "2": 0.25,
      "3": 0.2,
      "4": 0.15,
      "5": 0.1,
    },
    color_probabilities: {
      white: 1.0,
      green: 0.0,
      blue: 0.0,
      purple: 0.0,
      orange: 0.0,
      black: 0.0,
    },
  };
}

function makeRoll(refreshType) {
  if (!pending) {
    pending = {
      roll_id: "00000000-0000-4000-8000-000000000009",
      random_matrix: Array.from({ length: 8 }, (_, index) => [
        index % 2 === 0 ? 0.2 : 0.7,
        (index % 5) / 5 + 0.01,
        0.01,
      ]),
    };
  }
  pending.refresh_type = refreshType;
  pending.signature = `signature-${refreshType}`;
  return {
    key_stale: false,
    roll_id: pending.roll_id,
    signature: pending.signature,
    random_matrix: pending.random_matrix,
    draw_key: makeDrawKey(),
    expires_at: "2026-06-11T00:00:00.000Z",
  };
}

function makeConfirmedCards() {
  return pending.random_matrix.map((_, index) => {
    const deckId = index % 2 === 0 ? 1 : 2;
    const number = (index % 5) + 1;
    const cardDefId = deckId * 100 + number;
    return {
      slot_index: index,
      card_def_id: cardDefId,
      color: "white",
      card_def: {
        id: cardDefId,
        number,
        name: `类型切换子卡${number}`,
        deck_name: deckId === 1 ? "类型测试一" : "类型测试二",
        series_name: "类型切换测试系列",
        description: "用于刷新类型切换验证。",
        image_url: "",
      },
    };
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/__health") {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.method === "GET" && req.url === "/api/game/draw-key") {
    sendSuccess(res, makeDrawKey());
    return;
  }

  if (req.method === "POST" && req.url === "/api/game/refresh-pool/prepare") {
    const body = await readBody(req);
    sendSuccess(res, makeRoll(body.type || "free"));
    return;
  }

  if (req.method === "POST" && req.url === "/api/game/refresh-pool/confirm") {
    const body = await readBody(req);
    if (!pending || body.roll_id !== pending.roll_id || body.signature !== pending.signature) {
      sendJson(res, 400, { success: false, error: "pending roll mismatch" });
      return;
    }
    sendSuccess(res, {
      roll_id: pending.roll_id,
      confirmed: true,
      cards: makeConfirmedCards(),
      profile: {
        id: 1,
        username: "type-switch-test",
        level: 1,
        exp: 0,
        gold: 1000,
        gems: 45,
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
  console.log(`draw type switch mock listening on ${port}`);
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

CCR_DRAW_TYPE_SWITCH_API_BASE="http://127.0.0.1:${PORT}/api" \
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/DrawRefreshTypeSwitchTest.tscn
