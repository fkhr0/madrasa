const { AsyncLocalStorage } = require("async_hooks");
const arabic = require("./arabic");

const LANGUAGES = ["ar", "en"];
const DEFAULT = process.env.DEFAULT_LANGUAGE === "en" ? "en" : "ar";
const store = new AsyncLocalStorage();

function currentLanguage() {
  return store.getStore()?.language ?? DEFAULT;
}

function inLanguage(language, work) {
  return store.run({ language: normalize(language) }, work);
}

function normalize(language) {
  const code = String(language ?? "").slice(0, 2).toLowerCase();
  return LANGUAGES.includes(code) ? code : DEFAULT;
}

function t(template, args = [], language = currentLanguage()) {
  let text = language === "ar" ? (arabic[template] ?? template) : template;
  args.forEach((value, i) => {
    text = text.split(`{${i}}`).join(String(value ?? ""));
  });
  return text;
}

function msg(template, ...args) {
  return { template, args };
}

function render(text, language = currentLanguage()) {
  if (text == null) return text;
  if (Array.isArray(text)) {
    return text.filter(Boolean).map((part) => render(part, language)).join("\n");
  }
  if (typeof text === "object") {
    const args = text.args.map((a) => (a && typeof a === "object" ? render(a, language) : a));
    return t(text.template, args, language);
  }
  return text;
}

function languageMiddleware(req, _res, next) {
  const asked =
    req.get("X-Language") ||
    (req.get("Accept-Language") ? req.acceptsLanguages(...LANGUAGES) : null);
  const language = asked ? normalize(asked) : DEFAULT;
  req.language = language;
  store.run({ language }, next);
}

module.exports = { t, msg, render, currentLanguage, inLanguage, languageMiddleware, LANGUAGES };
