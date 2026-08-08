import http from "node:http";

const port = Number(process.env.CCR_ACCOUNT_TEST_PORT || 18767);

const server = http.createServer((request, response) => {
  let body = "";
  request.on("data", (chunk) => {
    body += chunk;
  });
  request.on("end", () => {
    let payload = {};
    try {
      payload = body ? JSON.parse(body) : {};
    } catch {
      response.writeHead(400, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ success: false, error: "bad json" }));
      return;
    }

    if (request.url === "/api/auth/availability") {
      const data = {};
      if (typeof payload.username === "string") {
        const taken = payload.username.toLowerCase() === "takenuser";
        data.username = { available: !taken, reason: taken ? "TAKEN" : "AVAILABLE" };
      }
      if (typeof payload.email === "string") {
        const taken = payload.email.toLowerCase() === "used@example.com";
        data.email = { available: !taken, reason: taken ? "TAKEN" : "AVAILABLE" };
      }
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({ success: true, data }));
      return;
    }

    if (request.url === "/api/user/username-availability") {
      const taken = String(payload.username || "").toLowerCase() === "takenuser";
      response.writeHead(200, { "Content-Type": "application/json" });
      response.end(JSON.stringify({
        success: true,
        data: { username: { available: !taken, reason: taken ? "TAKEN" : "AVAILABLE" } },
      }));
      return;
    }

    response.writeHead(404, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ success: false, error: "not found" }));
  });
});

server.listen(port, "127.0.0.1", () => {
  process.stdout.write(`ACCOUNT_AVAILABILITY_MOCK ready port=${port}\n`);
});

for (const signal of ["SIGTERM", "SIGINT"]) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
