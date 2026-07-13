#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
PORT="${CCR_PERSISTENT_HTTP_PORT:-43114}"
MOCK_LOG="$(mktemp -t ccr-persistent-http.XXXXXX.log)"

cleanup() {
	if [[ -n "${MOCK_PID:-}" ]]; then
		kill "$MOCK_PID" >/dev/null 2>&1 || true
		wait "$MOCK_PID" >/dev/null 2>&1 || true
	fi
	rm -f "$MOCK_LOG"
}
trap cleanup EXIT

CCR_PERSISTENT_HTTP_PORT="$PORT" node >"$MOCK_LOG" 2>&1 <<'NODE' &
const http = require("http");

const port = Number(process.env.CCR_PERSISTENT_HTTP_PORT || 43114);
let nextSocketId = 0;
const socketIds = new WeakMap();
const socketRequestCounts = new WeakMap();

const server = http.createServer((req, res) => {
  if (!socketIds.has(req.socket)) {
    socketIds.set(req.socket, ++nextSocketId);
    socketRequestCounts.set(req.socket, 0);
  }

  if (req.method === "GET" && req.url === "/api/health") {
    const requestCount = (socketRequestCounts.get(req.socket) || 0) + 1;
    socketRequestCounts.set(req.socket, requestCount);
    const closeAfterResponse = requestCount === 3;
    res.writeHead(200, {
      "content-type": "application/json",
      "connection": closeAfterResponse ? "close" : "keep-alive",
      "keep-alive": "timeout=30, max=100",
    });
    res.end(JSON.stringify({
      success: true,
      data: {
        socket_id: socketIds.get(req.socket),
        opened_sockets: nextSocketId,
        closed_after_response: closeAfterResponse,
      },
    }));
    return;
  }

  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ success: false, error: "not found" }));
});

server.keepAliveTimeout = 30000;
server.listen(port, "127.0.0.1", () => {
  console.log(`persistent HTTP mock listening on ${port}`);
});
NODE
MOCK_PID=$!

for _attempt in {1..40}; do
	if curl -fsS "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
		break
	fi
	sleep 0.1
done

if ! curl -fsS "http://127.0.0.1:${PORT}/api/health" >/dev/null 2>&1; then
	echo "Mock API failed to start. Log:" >&2
	cat "$MOCK_LOG" >&2
	exit 1
fi

CCR_PERSISTENT_HTTP_API_BASE="http://127.0.0.1:${PORT}/api" \
"$GODOT_BIN" --headless --path "$PROJECT_ROOT" res://Scenes/Tests/PersistentHttpTransportTest.tscn
