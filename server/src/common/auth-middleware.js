const config = require("../config");
const { HttpError } = require("./http");
const { rememberLanguage } = require("../features/users/language");

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
    rememberLanguage(req.user.id, req.language);
    next();
  } catch {
    throw new HttpError(401, "Your session has expired.");
  }
}

function requireRole(...roles) {
  return (req, _res, next) => {
    if (!roles.includes(req.user?.role)) {
      throw new HttpError(403, "You don't have access to this.");
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
