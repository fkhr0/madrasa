// Remembers answers so the database isn't asked the same thing again and again.
const config = require("../config");

const local = new Map(); // key -> { value, until }
const MAX_LOCAL = 500;

/** The text kept under [key], or null. */
async function readText(key) {
  if (config.redisUrl) {
    return require("./redis").client().get(`cache:${key}`).catch(() => null);
  }
  const hit = local.get(key);
  return hit && hit.until > Date.now() ? hit.value : null;
}

async function writeText(key, text, seconds) {
  if (config.redisUrl) {
    await require("./redis").client().set(`cache:${key}`, text, "EX", seconds).catch(() => {});
    return;
  }
  if (local.size >= MAX_LOCAL) local.clear(); // simple: never grows without end
  local.set(key, { value: text, until: Date.now() + seconds * 1000 });
}

/** compute()'s answer for [key], worked out at most once every [seconds]. */
async function cached(key, seconds, compute) {
  const hit = await readText(key);
  if (hit) return JSON.parse(hit);
  const value = await compute();
  await writeText(key, JSON.stringify(value), seconds);
  return value;
}

/**
 * Each school has a version number; it is part of every key, so raising it
 * (forgetSchool) makes all the old answers unreachable at once.
 */
const localVersions = new Map();

async function schoolVersion(institutionId) {
  if (!config.redisUrl) return localVersions.get(institutionId) ?? 0;
  const redis = require("./redis").client();
  return Number(await redis.get(`cache:school:${institutionId}:version`).catch(() => null)) || 0;
}

/** cached() for one school's data, forgotten as soon as the school changes it. */
async function cachedForSchool(institutionId, key, compute) {
  const version = await schoolVersion(institutionId);
  // 10 minutes at most anyway (a change made outside the API, by hand).
  return cached(`school:${institutionId}:v${version}:${key}`, 10 * 60, compute);
}

/** The school changed its year, classes, timetable or people. */
async function forgetSchool(institutionId) {
  if (!config.redisUrl) {
    localVersions.set(institutionId, (localVersions.get(institutionId) ?? 0) + 1);
    return;
  }
  const redis = require("./redis").client();
  await redis.incr(`cache:school:${institutionId}:version`).catch(() => {});
}

/** Paths whose answers change without anyone saving anything. */
const LIVE = /^\/(auth|messages|notifications|transport|files|days|health|reports\/today)(\/|$)/;

/** Writes that don't change cached answers (chats, GPS, uploads, sign-in). */
const NOT_A_CHANGE = /^\/(auth|messages|notifications|files|transport\/routes\/[^/]+\/trip)(\/|$)/;

/**
 * Middleware: GET answers kept per person, language and address, until the
 * school's version goes up (any change, see forgetSchoolOnChange) or 5 minutes
 * pass.
 */
function cacheResponses(req, res, next) {
  if (req.method !== "GET" || LIVE.test(req.path)) return next();
  let user;
  try {
    user = require("../features/auth/tokens").verifyToken(
      (req.headers.authorization || "").slice(7),
      "access",
    );
  } catch {
    return next(); // not signed in: the route answers (or refuses) itself
  }
  schoolVersion(user.inst)
    .then(async (version) => {
      const key = `get:${user.inst}:v${version}:${user.sub}:${req.language}:${req.originalUrl}`;
      const hit = await readText(key);
      require("./metrics").cacheLookups.inc({ result: hit ? "hit" : "miss" });
      if (hit) {
        res.type("json").send(hit); // ETag and 304 as usual
        return;
      }
      const json = res.json.bind(res);
      res.json = (body) => {
        if (res.statusCode === 200) writeText(key, JSON.stringify(body), 5 * 60);
        return json(body);
      };
      next();
    })
    .catch(() => next());
}

/**
 * Middleware: any successful change in a school forgets its cached answers -
 * before the answer goes out, so the next screen anyone opens already shows
 * the change.
 */
function forgetSchoolOnChange(req, res, next) {
  if (req.method === "GET" || req.method === "HEAD" || req.method === "OPTIONS") return next();
  if (NOT_A_CHANGE.test(req.path)) return next();
  const end = res.end.bind(res);
  res.end = (...args) => {
    const school = req.user?.institutionId;
    if (!school || res.statusCode >= 400) return end(...args);
    forgetSchool(school).finally(() => end(...args));
    return res;
  };
  next();
}

module.exports = { cached, cachedForSchool, forgetSchool, forgetSchoolOnChange, cacheResponses };
