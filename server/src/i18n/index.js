// The server's texts in each person's language (Arabic or English), the same
// way the app does it: the English text is the key, values go in numbered slots
// {0}, {1}..., and arabic.js has the Arabic.
const { AsyncLocalStorage } = require("async_hooks");
const arabic = require("./arabic");

const LANGUAGES = ["ar", "en"];
// Arabic unless the app says otherwise (tests use English).
const DEFAULT = process.env.DEFAULT_LANGUAGE === "en" ? "en" : "ar";
const store = new AsyncLocalStorage();

/** "ar" or "en": the language of the request being handled. */
function currentLanguage() {
  return store.getStore()?.language ?? DEFAULT;
}

/** Runs [work] as if a request in [language] were being handled (jobs). */
function inLanguage(language, work) {
  return store.run({ language: normalize(language) }, work);
}

function normalize(language) {
  const code = String(language ?? "").slice(0, 2).toLowerCase();
  return LANGUAGES.includes(code) ? code : DEFAULT;
}

/** [template] in [language], with its slots filled. */
function t(template, args = [], language = currentLanguage()) {
  let text = language === "ar" ? (arabic[template] ?? template) : template;
  args.forEach((value, i) => {
    text = text.split(`{${i}}`).join(String(value ?? ""));
  });
  return text;
}

/** A text to render later, in each reader's language. */
function msg(template, ...args) {
  return { template, args };
}

/**
 * Text in [language]: a plain string (as is), a msg(), or a list of them
 * (one per line).
 */
function render(text, language = currentLanguage()) {
  if (text == null) return text;
  if (Array.isArray(text)) {
    return text.filter(Boolean).map((part) => render(part, language)).join("\n");
  }
  if (typeof text === "object") {
    // Values can be msg() too, e.g. a translated exam type inside a title.
    const args = text.args.map((a) => (a && typeof a === "object" ? render(a, language) : a));
    return t(text.template, args, language);
  }
  return text;
}

/** Express middleware: the request's language, for everything it does. */
function languageMiddleware(req, _res, next) {
  // The app's choice first, then the browser's; with neither, the default.
  const asked =
    req.get("X-Language") ||
    (req.get("Accept-Language") ? req.acceptsLanguages(...LANGUAGES) : null);
  const language = asked ? normalize(asked) : DEFAULT;
  req.language = language;
  store.run({ language }, next);
}

module.exports = { t, msg, render, currentLanguage, inLanguage, languageMiddleware, LANGUAGES };
