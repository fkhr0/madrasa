// Starts the API: connect to the database, bring it up to date, add demo data
// to an empty database, then listen.
const fs = require("fs");
const path = require("path");
const config = require("./config");
const { connect, close, withLock } = require("./db/database");
const { migrate } = require("./db/migrate");
const { seedDemoSchool } = require("./db/seed");
const { addMissingOfficialHolidaysEverywhere } = require("./features/institution/official-holidays");
const { addDefaultPeriodsEverywhere } = require("./features/timetable/default-periods");
const { createApp } = require("./app");

/** Migrations, the platform's defaults, then the demo school (when wanted). */
async function prepareDatabase() {
  const applied = await migrate();
  const added = await seedDemoSchool({
    beforeHistory: {
      // Official holidays and bell times, for every school (the demo too).
      defaults: async () => {
        const holidays = await addMissingOfficialHolidaysEverywhere();
        if (holidays) console.log(`Official holidays added: ${holidays}`);
        const bellTimes = await addDefaultPeriodsEverywhere();
        if (bellTimes) console.log(`Default bell times given to ${bellTimes} school(s).`);
      },
    },
  });
  // Schools made later get theirs too.
  await addMissingOfficialHolidaysEverywhere();
  await addDefaultPeriodsEverywhere();
  if (added.length) console.log(`Demo school: ${added.join(", ")}`);
  return { applied, seeded: added.includes("people and the study year") };
}

async function main() {
  config.checkProductionSettings();
  const engine = await connect();
  // Several servers may start at once (a new version rolling out): one at a
  // time brings the database up to date and adds what is missing.
  const { applied, seeded } = await withLock("startup", prepareDatabase);
  // In the background: drawing lines on the roads needs the internet.
  require("./features/transport/roads").fillMissingRoads();
  // Background jobs: reminders, scheduled announcements, nightly upkeep...
  require("./jobs").registerJobs();
  await require("./jobs/queue").startJobs();

  console.log(
    `Database: ${engine.name === "pglite" ? `local (${config.localDataDir})` : "PostgreSQL"}`,
  );
  if (applied.length) console.log(`Migrations applied: ${applied.join(", ")}`);
  if (seeded) {
    console.log("Demo data added (password: DEMO_PASSWORD in .env).");
  }

  const server = createApp().listen(config.port, () => {
    console.log(`School API listening on http://localhost:${config.port}`);
    if (fs.existsSync(config.webDir)) {
      console.log(`The app: open http://localhost:${config.port} in Chrome`);
    }
  });

  // Live updates for the app (chat, notifications, the bus).
  require("./realtime/hub").attach(server);

  server.on("error", async (err) => {
    if (err.code === "EADDRINUSE") {
      console.error(
        `Port ${config.port} is already in use. Is the school server already ` +
          "running? Stop it with stop-school.bat, or set another PORT.",
      );
    } else {
      console.error("Server error:", err);
    }
    await close();
    process.exit(1);
  });

  // Close cleanly (Ctrl+C, hosting restarts) so PGlite saves its files.
  const stop = async () => {
    server.close();
    await require("./jobs/queue").stopJobs();
    await require("./common/redis").closeRedis();
    await close();
    process.exit(0);
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);

  // stop-school.bat asks for a clean stop by creating this file
  // (Windows has no gentle "kill", and the database should close properly).
  const stopFlag = path.join(__dirname, "..", "stop.flag");
  setInterval(() => {
    if (fs.existsSync(stopFlag)) stop();
  }, 1000).unref();
}

main().catch((err) => {
  console.error("Could not start:", err);
  process.exit(1);
});
