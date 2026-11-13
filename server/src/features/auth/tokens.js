// Sign-in tokens.
const crypto = require("crypto");
const jwt = require("jsonwebtoken");
const config = require("../../config");
const { query, queryOne } = require("../../db/database");
const { HttpError } = require("../../common/http");

const sha256 = (text) => crypto.createHash("sha256").update(text).digest("hex");

/** What each signed token is for. */
const PURPOSE = { access: "access", file: "file" };

/** The token's payload, or throws: wrong key, expired, other purpose, other algorithm. */
function verifyToken(token, purpose) {
  return jwt.verify(String(token ?? ""), config.jwt.accessSecret, {
    algorithms: ["HS256"],
    audience: purpose,
  });
}

function signAccessToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role, inst: user.institution_id },
    config.jwt.accessSecret,
    { expiresIn: config.jwt.accessTtl, algorithm: "HS256", audience: PURPOSE.access },
  );
}

/** A short-lived link to download one file. */
function signFileToken(fileId, expiresIn) {
  return jwt.sign({ file: fileId }, config.jwt.accessSecret, {
    expiresIn,
    algorithm: "HS256",
    audience: PURPOSE.file,
  });
}

/** Starts a new session (one per signed-in device). Returns the refresh token. */
async function createSession(userId) {
  const id = crypto.randomUUID();
  const secret = crypto.randomBytes(32).toString("hex");
  const days = config.jwt.refreshTtlDays;

  await query(
    `INSERT INTO sessions (id, user_id, token_hash, expires_at)
     VALUES ($1, $2, $3, now() + make_interval(days => $4))`,
    [id, userId, sha256(secret), days],
  );

  return `${id}.${secret}`;
}

/**
 * Checks a refresh token and replaces it. Returns { userId, refreshToken }.
 * Throws 401 when it is unknown, expired, revoked or already used.
 */
async function rotateSession(refreshToken) {
  const session = await findSession(refreshToken);
  await revoke(session.id);

  return {
    userId: session.user_id,
    refreshToken: await createSession(session.user_id),
  };
}

/** Signs one device out. Unknown tokens are ignored (already signed out). */
async function endSession(refreshToken) {
  try {
    const session = await findSession(refreshToken);
    await revoke(session.id);
  } catch {
    // Nothing to do.
  }
}

async function findSession(refreshToken) {
  const [id, secret] = String(refreshToken || "").split(".");
  if (!id || !secret) throw new HttpError(401, "Please sign in again.");

  const session = await queryOne(
    `SELECT id, user_id, token_hash, revoked_at, expires_at < now() AS expired
     FROM sessions WHERE id = $1`,
    [id],
  );
  if (!session) throw new HttpError(401, "Please sign in again.");

  const matches = crypto.timingSafeEqual(
    Buffer.from(session.token_hash),
    Buffer.from(sha256(secret)),
  );
  if (!matches || session.revoked_at || session.expired) {
    throw new HttpError(401, "Please sign in again.");
  }

  return session;
}

const revoke = (sessionId) =>
  query("UPDATE sessions SET revoked_at = now() WHERE id = $1", [sessionId]);

/** Signs every device of a user out (after a password change). */
const endAllSessions = (userId, exceptSessionOf) =>
  query(
    `UPDATE sessions SET revoked_at = now()
     WHERE user_id = $1 AND revoked_at IS NULL AND id <> $2`,
    [userId, String(exceptSessionOf || "").split(".")[0]],
  );

module.exports = {
  PURPOSE,
  verifyToken,
  signFileToken,
  signAccessToken,
  createSession,
  rotateSession,
  endSession,
  endAllSessions,
};
