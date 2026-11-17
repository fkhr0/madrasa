const config = require("../config");

const local = new Map();
const MAX_LOCAL = 500;

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
  if (local.size >= MAX_LOCAL) local.clear();
  local.set(key, { value: text, until: Date.now() + seconds * 1000 });
}

async function cached(key, seconds, compute) {
  const hit = await readText(key);
  if (hit) return JSON.parse(hit);
  const value = await compute();
  await writeText(key, JSON.stringify(value), seconds);
  return value;
}

const localVersions = new Map();

async function schoolVersion(institutionId) {
  if (!config.redisUrl) return localVersions.get(institutionId) ?? 0;
  const redis = require("./redis").client();
  return Number(await redis.get(`cache:school:${institutionId}:version`).catch(() => null)) || 0;
}

async function cachedForSchool(institutionId, key, compute) {
  const version = await schoolVersion(institutionId);
  return cached(`school:${institutionId}:v${version}:${key}`, 10 * 60, compute);
}

async function forgetSchool(institutionId) {
  if (!config.redisUrl) {
    localVersions.set(institutionId, (localVersions.get(institutionId) ?? 0) + 1);
    return;
  }
  const redis = require("./redis").client();
  await redis.incr(`cache:school:${institutionId}:version`).catch(() => {});
}

const LIVE = /^\/(auth|messages|notifications|transport|files|days|health|reports\/today)(\/|$)/;

const NOT_A_CHANGE = /^\/(auth|messages|notifications|files|transport\/routes\/[^/]+\/trip)(\/|$)/;

function cacheResponses(req, res, next) {
  if (req.method !== "GET" || LIVE.test(req.path)) return next();
  let user;
  try {
    user = require("../features/auth/tokens").verifyToken(
      (req.headers.authorization || "").slice(7),
      "access",
    );
  } catch {
    return next();
  }
  schoolVersion(user.inst)
    .then(async (version) => {
      const key = `get:${user.inst}:v${version}:${user.sub}:${req.language}:${req.originalUrl}`;
      const hit = await readText(key);
      require("./metrics").cacheLookups.inc({ result: hit ? "hit" : "miss" });
      if (hit) {
        res.type("json").send(hit);
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
