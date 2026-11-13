// Every setting the server reads from the environment, in one place.
// Values come from .env (see .env.example) or the hosting dashboard.
require("dotenv").config({ quiet: true });

const isProduction = process.env.NODE_ENV === "production";

function secret(name, devDefault) {
  const value = process.env[name];
  if (value) return value;
  // A missing secret online would let anyone forge tokens: refuse to start.
  if (isProduction) throw new Error(`${name} must be set in production`);
  return devDefault;
}

module.exports = {
  isProduction,
  port: Number(process.env.PORT) || 3000,

  // Empty = PGlite (PostgreSQL inside Node) stored in .data/pglite.
  databaseUrl: process.env.DATABASE_URL || "",
  // Connections each server keeps open. Neon free allows ~100 in all; keep
  // (servers × DB_POOL_SIZE) + the worker well under it.
  dbPoolSize: Number(process.env.DB_POOL_SIZE || 10),
  localDataDir: process.env.LOCAL_DATA_DIR || ".data/pglite",
  // Nightly backups. Online, copy this folder to another place too.
  backupsDir: process.env.BACKUPS_DIR || ".data/backups",
  // A bucket away from this server for copies of the backups (Oracle Object
  // Storage, Cloudflare R2, AWS S3). Empty bucket = off.
  backupS3: {
    endpoint: process.env.BACKUP_S3_ENDPOINT || "",
    region: process.env.BACKUP_S3_REGION || "auto",
    bucket: process.env.BACKUP_S3_BUCKET || "",
    accessKeyId: process.env.BACKUP_S3_ACCESS_KEY_ID || "",
    secretAccessKey: process.env.BACKUP_S3_SECRET_ACCESS_KEY || "",
    pathStyle: process.env.BACKUP_S3_PATH_STYLE === "true",
  },
  // pg_dump, for backing up a real PostgreSQL (in PATH, or its full path).
  pgDump: process.env.PG_DUMP || "pg_dump",

  // Uploaded files (homework, attachments). On a host, point it at a disk
  // that survives restarts.
  uploadsDir: process.env.UPLOADS_DIR || ".data/uploads",
  // Where uploaded files live: "local" (uploadsDir) or "s3" (a bucket all
  // servers share: Cloudflare R2, MinIO, AWS S3).
  storage: process.env.STORAGE || "local",
  s3: {
    endpoint: process.env.S3_ENDPOINT || "",
    region: process.env.S3_REGION || "auto",
    bucket: process.env.S3_BUCKET || "",
    accessKeyId: process.env.S3_ACCESS_KEY_ID || "",
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || "",
    pathStyle: process.env.S3_PATH_STYLE === "true",
  },
  // Largest upload: videos (a lesson recording) and everything else.
  maxUploadMb: Number(process.env.MAX_UPLOAD_MB || 10),
  maxVideoMb: Number(process.env.MAX_VIDEO_MB || 50),

  jwt: {
    accessSecret: secret("JWT_ACCESS_SECRET", "dev-access-secret"),
    refreshSecret: secret("JWT_REFRESH_SECRET", "dev-refresh-secret"),
    // Short-lived access token; the app refreshes it silently.
    accessTtl: "15m",
    refreshTtlDays: 30,
  },

  // The app's web build (flutter build web), served at http://localhost:3000/
  // so the whole app runs from this PC without Flutter's debug tools.
  webDir: process.env.WEB_DIR || require("path").join(__dirname, "../../build/web"),

  // Background jobs (BullMQ).
  redisUrl: process.env.REDIS_URL || "",
  // Shown on the public privacy and account deletion pages (Google Play
  // links to them).
  operatorName: process.env.OPERATOR_NAME || "the Madrasa team",
  contactEmail: process.env.CONTACT_EMAIL || "privacy@madrasa.iq",
  policyUpdated: process.env.POLICY_UPDATED || "2026-11-09",
  // Firebase (Android notifications): the service account file from the
  // Firebase console. Empty = Android phones get no notifications while closed.
  firebaseServiceAccountFile: process.env.FIREBASE_SERVICE_ACCOUNT_FILE || "",
  // false = this process only queues jobs; a separate worker
  // (node src/worker.js) runs them. On one PC, run them here.
  runWorker: (process.env.RUN_WORKER ?? "true") === "true",
  // Jobs and reminders follow the school's clock.
  timeZone: process.env.TIME_ZONE || "Asia/Baghdad",

  seedDemoData: (process.env.SEED_DEMO_DATA ?? (isProduction ? "false" : "true")) === "true",
  // "Try the demo": a demo school anyone can open from the sign-in page
  // (no password), reset every night. Its accounts get random passwords.
  demoMode: process.env.DEMO_MODE === "true",
  // The demo school's language (Arabic like a real Iraqi school; the tests use English).
  demoLanguage: process.env.DEMO_LANGUAGE || process.env.DEFAULT_LANGUAGE || "ar",
  demoPassword: process.env.DEMO_PASSWORD || "demo1234",

  // ---------- Security ----------
  // Other websites allowed to call the API (comma-separated). The app served
  // by this server never needs one.
  corsOrigins: (process.env.CORS_ORIGINS || "").split(",").map((o) => o.trim()).filter(Boolean),
  // true = the browser only reports what the Content Security Policy would block.
  cspReportOnly: process.env.CSP_REPORT_ONLY === "true",
  // How many proxies (Caddy, Cloudflare) stand in front, so limits see the
  // real address. 0 when the server is reached directly.
  trustProxy: Number(process.env.TRUST_PROXY ?? (isProduction ? 1 : 0)),
  // Tests make hundreds of requests quickly.
  rateLimitsOff: process.env.RATE_LIMITS === "off",
  // Password hashing work (12 ≈ a quarter second; slows down guessing).
  bcryptCost: Number(process.env.BCRYPT_COST || 12),
};

/**
 * Refuses to start online with settings that would be unsafe there.
 * Called by server.js and worker.js.
 */
function checkProductionSettings(settings = module.exports) {
  if (!settings.isProduction) return;
  const problems = [];
  for (const name of ["JWT_ACCESS_SECRET", "JWT_REFRESH_SECRET"]) {
    if ((process.env[name] || "").length < 32) problems.push(`${name} must be a long random string`);
  }
  if (process.env.JWT_ACCESS_SECRET && process.env.JWT_ACCESS_SECRET === process.env.JWT_REFRESH_SECRET) {
    problems.push("JWT_ACCESS_SECRET and JWT_REFRESH_SECRET must differ");
  }
  if (!settings.databaseUrl) problems.push("DATABASE_URL must point to PostgreSQL (PGlite is for one PC)");
  if (settings.seedDemoData) problems.push("SEED_DEMO_DATA must be false (demo accounts share one password)");
  if (settings.storage === "s3" && !(settings.s3?.bucket && settings.s3?.accessKeyId)) {
    problems.push("STORAGE=s3 needs S3_BUCKET, S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY");
  }
  // Each server would make its own push keys, and phones subscribed
  // through one server would stop getting notifications from another.
  if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
    problems.push("VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY must be set (npx web-push generate-vapid-keys)");
  }
  if (problems.length) {
    throw new Error(`Unsafe production settings:\n  - ${problems.join("\n  - ")}`);
  }
}

module.exports.checkProductionSettings = checkProductionSettings;
