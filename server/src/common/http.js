// Small helpers shared by every feature.
const { z } = require("zod");
const { t, render, currentLanguage } = require("../i18n");

/**
 * An error the client should see, with its HTTP status. The message is the
 * English text with slots for values, sent in the caller's language:
 *   new HttpError(400, "{0} doesn't study this subject.", [className])
 */
class HttpError extends Error {
  constructor(status, message, args = []) {
    super(t(message, args, "en"));
    this.status = status;
    this.template = message;
    this.args = args;
  }
}

// Arabic messages for zod's own checks ("too short"...).
const arabicChecks = z.locales.ar().localeError;

/**
 * Checks a request body against a zod schema. Returns the clean data or
 * throws 400 with the first problem in plain words.
 */
function validate(schema, body) {
  const arabic = currentLanguage() === "ar";
  const result = schema.safeParse(body ?? {}, arabic ? { error: arabicChecks } : undefined);
  if (result.success) return result.data;

  const issue = result.error.issues[0];
  const field = issue.path.join(".");
  // Our own messages ("use YYYY-MM-DD") are in the dictionary; zod's are
  // already in the right language.
  const message = t(issue.message);
  throw new HttpError(400, field ? "{0}: {1}" : "{1}", [t(field), message]);
}

/** Express error handler: known errors keep their status, others become 500. */
function errorHandler(err, req, res, _next) {
  const language = req.language;
  if (err instanceof HttpError) {
    return res
      .status(err.status)
      .json({ error: render({ template: err.template, args: err.args }, language) });
  }
  // Malformed JSON body.
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ error: t("The request body is not valid JSON.", [], language) });
  }
  // Too big (uploads over the limit).
  if (err.type === "entity.too.large") {
    return res.status(413).json({ error: t("The file is too big.", [], language) });
  }

  console.error(`[${req.method} ${req.originalUrl}]`, err);
  res.status(500).json({ error: t("Something went wrong on the server.", [], language) });
}

/** "2026-10-03" */
const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "use YYYY-MM-DD");

module.exports = { HttpError, validate, errorHandler, isoDate, z };
