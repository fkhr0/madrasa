const cors = require("cors");
const helmet = require("helmet");
const { rateLimit, ipKeyGenerator } = require("express-rate-limit");
const config = require("../config");
const { t } = require("../i18n");

function corsMiddleware() {
  return cors({
    origin: (origin, done) => done(null, originAllowed(origin)),
    allowedHeaders: ["Authorization", "Content-Type", "X-Language", "X-File-Name", "If-None-Match", "Range"],
    exposedHeaders: ["ETag"],
    maxAge: 600,
  });
}

const devOrigin = /^https?:\/\/(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+)(:\d+)?$/;

function originAllowed(origin, host) {
  if (!origin) return true;
  if (config.corsOrigins.includes(origin)) return true;
  if (host && new URL(origin).host === host) return true;
  return !config.isProduction && devOrigin.test(origin);
}

function headersMiddleware() {
  return helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        "default-src": ["'self'"],
        "script-src": ["'self'", "'wasm-unsafe-eval'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "img-src": ["'self'", "data:", "blob:", "https://tile.openstreetmap.org"],
        "font-src": ["'self'", "data:", "https://fonts.gstatic.com"],
        "connect-src": ["'self'", "ws:", "wss:", "https://tile.openstreetmap.org", "https://fonts.gstatic.com"],
        "worker-src": ["'self'", "blob:"],
        "manifest-src": ["'self'"],
        "frame-ancestors": ["'none'"],
        "base-uri": ["'self'"],
        "object-src": ["'none'"],
        "form-action": ["'self'"],
      },
      reportOnly: config.cspReportOnly,
    },
    strictTransportSecurity: config.isProduction
      ? { maxAge: 31536000, includeSubDomains: true }
      : false,
    crossOriginEmbedderPolicy: false,
    referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  });
}

function store(prefix) {
  if (!config.redisUrl) return undefined;
  const { RedisStore } = require("rate-limit-redis");
  const redis = require("./redis").client();
  return new RedisStore({ prefix: `rl:${prefix}:`, sendCommand: (...args) => redis.call(...args) });
}

function limiter(prefix, { windowMinutes, max, key, message }) {
  return rateLimit({
    windowMs: windowMinutes * 60_000,
    limit: max,
    standardHeaders: "draft-7",
    legacyHeaders: false,
    keyGenerator: key,
    store: store(prefix),
    skip: () => config.rateLimitsOff,
    handler: (req, res) =>
      res.status(429).json({ error: t(message, [], req.language) }),
  });
}

const addressOf = (req) => ipKeyGenerator(req.ip);

const apiLimit = limiter("api", {
  windowMinutes: 1,
  max: 300,
  key: (req) => bearerSubject(req) ?? addressOf(req),
  message: "Too many requests. Please wait a moment.",
});

const signInLimit = limiter("signin", {
  windowMinutes: 15,
  max: 10,
  key: (req) => `${addressOf(req)}:${String(req.body?.schoolId ?? "").toUpperCase()}`,
  message: "Too many sign-in attempts. Try again in 15 minutes.",
});

const resetLimit = limiter("reset", {
  windowMinutes: 60,
  max: 5,
  key: (req) => addressOf(req),
  message: "Too many requests. Please wait a moment.",
});

const uploadLimit = limiter("upload", {
  windowMinutes: 10,
  max: 40,
  key: (req) => bearerSubject(req) ?? addressOf(req),
  message: "Too many uploads. Please wait a moment.",
});

function bearerSubject(req) {
  const header = req.headers.authorization || "";
  if (!header.startsWith("Bearer ")) return null;
  try {
    const payload = JSON.parse(Buffer.from(header.split(".")[1], "base64url").toString());
    return typeof payload.sub === "string" ? `user:${payload.sub}` : null;
  } catch {
    return null;
  }
}

module.exports = {
  originAllowed,
  corsMiddleware,
  headersMiddleware,
  apiLimit,
  signInLimit,
  resetLimit,
  uploadLimit,
};
