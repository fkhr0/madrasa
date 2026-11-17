const { WebSocketServer } = require("ws");
const { originAllowed } = require("../common/security");
const config = require("../config");

const AUTH_WITHIN_MS = 10_000;
const PING_EVERY_MS = 30_000;

const SOCKETS_PER_PERSON = 5;

const sockets = new Map();

const CHANNEL = "live-events";

function attach(httpServer) {
  const wss = new WebSocketServer({
    server: httpServer,
    path: "/ws",
    maxPayload: 4096,
    verifyClient: ({ origin, req }) => {
      try {
        return originAllowed(origin, req.headers.host);
      } catch {
        return false;
      }
    },
  });
  if (config.redisUrl) listenToOtherServers();

  wss.on("connection", (socket) => {
    socket.isAlive = true;
    socket.on("pong", () => (socket.isAlive = true));
    const authTimer = setTimeout(() => socket.close(4001, "Sign in first"), AUTH_WITHIN_MS);

    socket.on("message", (data) => {
      if (socket.userId) return;
      let message;
      try {
        message = JSON.parse(String(data));
        const payload = require("../features/auth/tokens").verifyToken(message.token, "access");
        socket.userId = payload.sub;
      } catch {
        socket.close(4001, "Sign in again");
        return;
      }
      clearTimeout(authTimer);
      if (!sockets.has(socket.userId)) sockets.set(socket.userId, new Set());
      const mine = sockets.get(socket.userId);
      if (mine.size >= SOCKETS_PER_PERSON) {
        const oldest = mine.values().next().value;
        mine.delete(oldest);
        require("../common/metrics").liveConnections.dec();
        oldest.close(4008, "Too many connections");
      }
      mine.add(socket);
      require("../common/metrics").liveConnections.inc();
      socket.send(JSON.stringify({ type: "ready" }));
    });

    socket.on("close", () => {
      clearTimeout(authTimer);
      const mine = sockets.get(socket.userId);
      if (!mine) return;
      if (mine.delete(socket)) require("../common/metrics").liveConnections.dec();
      if (mine.size === 0) sockets.delete(socket.userId);
    });
  });

  const heartbeat = setInterval(() => {
    for (const socket of wss.clients) {
      if (!socket.isAlive) {
        socket.terminate();
        continue;
      }
      socket.isAlive = false;
      socket.ping();
    }
  }, PING_EVERY_MS);
  heartbeat.unref();
  wss.on("close", () => clearInterval(heartbeat));

  return wss;
}

function publish(userIds, event) {
  const ids = [...new Set(userIds)];
  if (!config.redisUrl) return deliver(ids, event);
  const redis = require("../common/redis").client();
  redis.publish(CHANNEL, JSON.stringify({ userIds: ids, event })).catch(() => {
    deliver(ids, event);
  });
}

function listenToOtherServers() {
  const subscriber = require("../common/redis").newConnection();
  subscriber.subscribe(CHANNEL).catch((e) => console.warn(`Live updates: ${e.message}`));
  subscriber.on("message", (_channel, text) => {
    try {
      const { userIds, event } = JSON.parse(text);
      deliver(userIds, event);
    } catch {
    }
  });
}

function deliver(userIds, event) {
  const text = JSON.stringify(event);
  for (const id of userIds) {
    for (const socket of sockets.get(id) ?? []) {
      try {
        socket.send(text);
      } catch {
      }
    }
  }
}

function onlineCount() {
  return sockets.size;
}

module.exports = { attach, publish, onlineCount };
