const { z } = require("zod");
const { t, render, currentLanguage } = require("../i18n");

class HttpError extends Error {
  constructor(status, message, args = []) {
    super(t(message, args, "en"));
    this.status = status;
    this.template = message;
    this.args = args;
  }
}

const arabicChecks = z.locales.ar().localeError;

function validate(schema, body) {
  const arabic = currentLanguage() === "ar";
  const result = schema.safeParse(body ?? {}, arabic ? { error: arabicChecks } : undefined);
  if (result.success) return result.data;

  const issue = result.error.issues[0];
  const field = issue.path.join(".");
  const message = t(issue.message);
  throw new HttpError(400, field ? "{0}: {1}" : "{1}", [t(field), message]);
}

function errorHandler(err, req, res, _next) {
  const language = req.language;
  if (err instanceof HttpError) {
    return res
      .status(err.status)
      .json({ error: render({ template: err.template, args: err.args }, language) });
  }
  if (err.type === "entity.parse.failed") {
    return res.status(400).json({ error: t("The request body is not valid JSON.", [], language) });
  }
  if (err.type === "entity.too.large") {
    return res.status(413).json({ error: t("The file is too big.", [], language) });
  }

  const url = String(req.originalUrl).slice(0, 300).replace(/\n|\r/g, "");
  const method = String(req.method).slice(0, 20).replace(/\n|\r/g, "");
  console.error("[%s %s]", method, url, err);
  res.status(500).json({ error: t("Something went wrong on the server.", [], language) });
}

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "use YYYY-MM-DD");

module.exports = { HttpError, validate, errorHandler, isoDate, z };
