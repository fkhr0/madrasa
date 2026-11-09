// Who is calling? Every route except sign-in needs a valid access token:
//   Authorization: Bearer <accessToken>
const config = require("../config");
const { HttpError } = require("./http");
const { rememberLanguage } = require("../features/users/language");

/** Puts { id, role, institutionId } on req.user, or answers 401. */
function requireAuth(req, _res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) throw new HttpError(401, "Please sign in.");

  try {
    const payload = require("../features/auth/tokens").verifyToken(token, "access");
    req.user = {
      id: payload.sub,
      role: payload.role,
      institutionId: payload.inst,
    };
    // Notifications to this person later use the language their app shows.
    rememberLanguage(req.user.id, req.language);
    next();
  } catch {
    // Expired or forged. The app refreshes and tries again.
    throw new HttpError(401, "Your session has expired.");
  }
}

/** Only these roles may continue, e.g. requireRole("admin"). */
function requireRole(...roles) {
  return (req, _res, next) => {
    if (!roles.includes(req.user?.role)) {
      throw new HttpError(403, "You don't have access to this.");
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
