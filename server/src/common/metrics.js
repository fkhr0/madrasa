// Numbers for Prometheus and Grafana: how many requests, how fast, how many
// failed, live connections, cache hits, plus Node's own (memory, CPU, event-
// loop delay).
const client = require("prom-client");

const registry = new client.Registry();
client.collectDefaultMetrics({ register: registry });

const requests = new client.Counter({
  name: "http_requests_total",
  help: "Requests answered, by route and status",
  labelNames: ["method", "route", "status"],
  registers: [registry],
});

const duration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Time to answer a request",
  labelNames: ["method", "route"],
  buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
  registers: [registry],
});

const liveConnections = new client.Gauge({
  name: "ws_connections",
  help: "Open live (WebSocket) connections",
  registers: [registry],
});

const cacheLookups = new client.Counter({
  name: "cache_lookups_total",
  help: "Server cache lookups, hit or miss",
  labelNames: ["result"],
  registers: [registry],
});

const signIns = new client.Counter({
  name: "sign_ins_total",
  help: "Sign-in attempts, by result",
  labelNames: ["result"],
  registers: [registry],
});

/**
 * Middleware: times every request. The route is the pattern
 * ("/people/:id"), not the address, so there are few distinct labels.
 */
function measureRequests(req, res, next) {
  const stop = duration.startTimer();
  res.on("finish", () => {
    const route = req.route ? `${req.baseUrl}${req.route.path}` : "unmatched";
    const labels = { method: req.method, route };
    stop(labels);
    requests.inc({ ...labels, status: res.statusCode });
  });
  next();
}

/** GET /metrics (Prometheus' text format). */
async function metricsPage(_req, res) {
  res.setHeader("Content-Type", registry.contentType);
  res.send(await registry.metrics());
}

module.exports = {
  registry,
  measureRequests,
  metricsPage,
  liveConnections,
  cacheLookups,
  signIns,
};
