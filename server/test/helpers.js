process.env.OSRM_URL = "off";
process.env.REDIS_URL = "";
process.env.DEFAULT_LANGUAGE = "en";
process.env.RATE_LIMITS = "off";
process.env.BCRYPT_COST = "4";
process.env.UPLOADS_DIR = require("path").join(require("os").tmpdir(), "school-test-uploads");
process.env.PUSH_KEYS_FILE = require("path").join(require("os").tmpdir(), "school-test-push-keys.json");
const request = require("supertest");
const { connect, close, query } = require("../src/db/database");
const { migrate } = require("../src/db/migrate");
const {
  seedDemoData,
  seedAcademics,
  seedAnnouncements,
  seedTimetable,
  seedAttendance,
  seedExams,
  seedAssignments,
  seedMessages,
  seedFinance,
  seedTasksAndResources,
  seedActivityLog,
  seedTransport,
} = require("../src/db/seed");
const { addMissingOfficialHolidaysEverywhere } = require("../src/features/institution/official-holidays");
const { addDefaultPeriodsEverywhere } = require("../src/features/timetable/default-periods");
const { registerJobs } = require("../src/jobs");
const { createApp } = require("../src/app");
const config = require("../src/config");

async function startTestApp() {
  if (onRealPostgres) {
    await useEmptyTestDatabase();
  } else {
    await connect({ dataDir: "memory://" });
  }
  await migrate();
  await seedDemoData();
  await seedAcademics();
  await seedAnnouncements();
  await seedTimetable();
  await seedTransport();
  await seedFinance();
  await addMissingOfficialHolidaysEverywhere();
  await addDefaultPeriodsEverywhere();
  registerJobs();
  await seedAttendance();
  await seedExams();
  await seedAssignments();
  await seedMessages();
  await seedTasksAndResources();
  await seedActivityLog();
  await query("UPDATE users SET language = 'en'");
  return createApp();
}

const onRealPostgres = process.env.npm_lifecycle_event === "test:pg";

async function useEmptyTestDatabase() {
  const url = new URL(process.env.TEST_DATABASE_URL || "");
  const name = url.pathname.slice(1);
  if (!/test/.test(name)) {
    throw new Error(`TEST_DATABASE_URL must name a test database (got "${name}")`);
  }

  const { Client } = require("pg");
  const server = new Client({ connectionString: Object.assign(new URL(url), { pathname: "/postgres" }).href });
  await server.connect();
  const exists = await server.query("SELECT 1 FROM pg_database WHERE datname = $1", [name]);
  if (exists.rowCount === 0) await server.query(`CREATE DATABASE "${name}"`);
  await server.end();

  config.databaseUrl = url.href;
  await connect();
  await query("DROP SCHEMA IF EXISTS public CASCADE");
  await query("CREATE SCHEMA public");
}

async function signIn(app, schoolId, password = config.demoPassword) {
  const res = await request(app)
    .post("/auth/login")
    .send({ schoolId, password })
    .expect(200);
  return res.body;
}

module.exports = { startTestApp, signIn, close, request };
