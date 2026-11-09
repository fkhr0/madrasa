// The Express app: middleware and routes. server.js starts it; the tests use it
// directly without opening a port.
const fs = require("fs");
const express = require("express");
const config = require("./config");
const { errorHandler } = require("./common/http");
const { db } = require("./db/database");

function createApp() {
  const app = express();
  const security = require("./common/security");

  // The real visitor address behind Caddy / Cloudflare (for the limits).
  app.set("trust proxy", config.trustProxy);
  const metrics = require("./common/metrics");
  app.use(metrics.measureRequests);
  // For Prometheus inside the server; Nginx refuses it from outside.
  app.get("/metrics", metrics.metricsPage);
  app.disable("x-powered-by");
  app.use(security.headersMiddleware());
  app.use(security.corsMiddleware());
  // Answers zipped on the way out: JSON lists and the app's 4 MB of
  // JavaScript shrink to about a quarter. (Photos and PDFs are skipped:
  // they are already compressed.)
  app.use(require("compression")());
  // Answers are one person's: the phone may keep them (and ask with ETag),
  // but no proxy or CDN in between may store or share them.
  app.use((_req, res, next) => {
    res.setHeader("Cache-Control", "private, no-cache");
    next();
  });
  // The caller's language (X-Language from the app) for everything below.
  app.use(require("./i18n").languageMiddleware);
  app.use(security.apiLimit);
  // Uploads read their own raw body, so they come before the JSON parser.
  app.use("/files", require("./features/files/files.routes"));
  app.use(express.json({ limit: "1mb" }));

  // Health check for the hosting service and the app's "server address" test.
  app.get("/health", (_req, res) =>
    res.json({
      ok: true,
      database: db().name,
      online: require("./realtime/hub").onlineCount(),
    }),
  );

  // Server cache (common/cache.js): any change in a school clears its
  // cached answers; GET answers come from the cache until then.
  const cache = require("./common/cache");
  app.use(cache.forgetSchoolOnChange);
  app.use(cache.cacheResponses);

  app.use("/auth", require("./features/auth/auth.routes"));
  app.use("/me", require("./features/users/me.routes"));
  app.use("/people", require("./features/people/people.routes"));
  app.use("/events", require("./features/events/events.routes"));
  app.use("/announcements", require("./features/announcements/announcements.routes"));
  app.use("/notifications", require("./features/notifications/notifications.routes"));
  app.use("/transport", require("./features/transport/transport.routes"));
  app.use("/academics", require("./features/academics/academics.routes"));
  app.use("/timetable", require("./features/timetable/timetable.routes"));
  app.use("/attendance", require("./features/attendance/attendance.routes"));
  app.use("/teaching", require("./features/teaching/teaching.routes"));
  app.use("/exams", require("./features/exams/exams.routes"));
  app.use("/assignments", require("./features/assignments/assignments.routes"));
  app.use("/messages", require("./features/messages/messages.routes"));
  app.use("/finance", require("./features/finance/finance.routes"));
  app.use("/reports", require("./features/reports/reports.routes"));
  app.use("/activity", require("./features/activity/activity.routes"));
  app.use("/days", require("./features/days/days.routes"));
  app.use("/tasks", require("./features/tasks/tasks.routes"));
  app.use("/resources", require("./features/resources/resources.routes"));
  app.use("/", require("./features/institution/institution.routes"));

  // The app itself, when it has been built (build-app.bat).
  if (fs.existsSync(config.webDir)) {
    app.use(
      express.static(config.webDir, {
        cacheControl: false,
        setHeaders: (res) => res.setHeader("Cache-Control", "no-cache"),
      }),
    );
  }

  // Public pages Google Play links to (no sign-in).
  for (const page of ["privacy", "delete-account"]) {
    const html = fs
      .readFileSync(require("path").join(__dirname, "..", "public", `${page}.html`), "utf8")
      .replaceAll("{{OPERATOR}}", config.operatorName)
      .replaceAll("{{EMAIL}}", config.contactEmail)
      .replaceAll("{{UPDATED}}", config.policyUpdated);
    app.get(`/${page}`, (_req, res) => {
      res.setHeader("Cache-Control", "public, max-age=3600");
      res.type("html").send(html);
    });
  }

  app.use((_req, res) => res.status(404).json({ error: "Not found." }));
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
