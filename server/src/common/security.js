// Protection for every request: which websites may call the API, security
// headers, and limits on how fast anyone can try things (sign-in guessing,
// floods of requests).
const cors = require("cors");
const helmet = require("helmet");
const { rateLimit, ipKeyGenerator } = require("express-rate-limit");
const config = require("../config");
const { t } = require("../i18n");

/** Websites allowed to call the API from a browser. */
function corsMiddleware() {
  return cors({
    // Not allowed: no CORS headers, so the browser blocks the answer.
    origin: (origin, done) => done(null, originAllowed(origin)),
    allowedHeaders: ["Authorization", "Content-Type", "X-Language", "X-File-Name", "If-None-Match", "Range"],
    // The app keeps answers by their version tag (304 when unchanged).
    exposedHeaders: ["ETag"],
    maxAge: 600,
  });
}

const devOrigin = /^https?:\/\/(localhost|127\.0\.0\.1|192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+)(:\d+)?$/;

/**
 * May a page from this origin talk to us? Also used for the WebSocket.
 * `host` is our own address, for pages we serve ourselves.
 */
function originAllowed(origin, host) {
  // No Origin: the Android app, curl, same-origin GETs.
  if (!origin) return true;
  if (config.corsOrigins.includes(origin)) return true;
  if (host && new URL(origin).host === host) return true;
  return !config.isProduction && devOrigin.test(origin);
}

/**
 * Security headers (helmet). The Content Security Policy only lets the page
 * load the app's own files, OpenStreetMap tiles and the WebSocket.
 */
function headersMiddleware() {
  return helmet({
    contentSecurityPolicy: {
      useDefaults: false,
      directives: {
        "default-src": ["'self'"],
        // Flutter runs as WebAssembly/CanvasKit from our own files.
        "script-src": ["'self'", "'wasm-unsafe-eval'"],
        "style-src": ["'self'", "'unsafe-inline'"],
        "img-src": ["'self'", "data:", "blob:", "https://tile.openstreetmap.org"],
        // Our fonts are bundled; Google's font host only for letters they
        // lack (emoji in chats), which Flutter fetches when needed.
        "font-src": ["'self'", "data:", "https://fonts.gstatic.com"],
        "connect-src": ["'self'", "ws:", "wss:", "https://tile.openstreetmap.org", "https://fonts.gstatic.com"],
        "worker-src": ["'self'", "blob:"],
        "manifest-src": ["'self'"],
        "frame-ancestors": ["'none'"],
        "base-uri": ["'self'"],
        "object-src": ["'none'"],
        "form-action": ["'self'"],
      },
      // CSP_REPORT_ONLY=true: the browser only warns (for checking a new build).
      reportOnly: config.cspReportOnly,
    },
    // HTTPS only, once the site is on HTTPS (Caddy / Cloudflare in front).
    strictTransportSecurity: config.isProduction
      ? { maxAge: 31536000, includeSubDomains: true }
      : false,
    // Maps tiles and fonts are loaded from other sites.
    crossOriginEmbedderPolicy: false,
    // Other sites get only our origin, never a path. OpenStreetMap refuses
    // map tiles with no Referer at all (its usage policy).
    referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  });
}

/** A Redis store for the limits when REDIS_URL is set (several servers). */
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
    // Tests send many requests from one address.
    skip: () => config.rateLimitsOff,
    handler: (req, res) =>
      res.status(429).json({ error: t(message, [], req.language) }),
  });
}

/** The visitor's address; a whole IPv6 block counts as one (one phone gets many). */
const addressOf = (req) => ipKeyGenerator(req.ip);

/** Every request: generous, per signed-in person (or address). */
const apiLimit = limiter("api", {
  windowMinutes: 1,
  max: 300,
  key: (req) => bearerSubject(req) ?? addressOf(req),
  message: "Too many requests. Please wait a moment.",
});

/** Sign-in: per address and per school ID, so guessing is slow. */
const signInLimit = limiter("signin", {
  windowMinutes: 15,
  max: 10,
  key: (req) => `${addressOf(req)}:${String(req.body?.schoolId ?? "").toUpperCase()}`,
  message: "Too many sign-in attempts. Try again in 15 minutes.",
});

/** Password reset requests: per address. */
const resetLimit = limiter("reset", {
  windowMinutes: 60,
  max: 5,
  key: (req) => addressOf(req),
  message: "Too many requests. Please wait a moment.",
});

/** Uploads: per person. */
const uploadLimit = limiter("upload", {
  windowMinutes: 10,
  max: 40,
  key: (req) => bearerSubject(req) ?? addressOf(req),
  message: "Too many uploads. Please wait a moment.",
});

/** The user ID inside a bearer token, without checking it (just for counting). */
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
