require("dotenv").config({ quiet: true });

const isProduction = process.env.NODE_ENV === "production";

function secret(name, devDefault) {
  const value = process.env[name];
  if (value) return value;
  if (isProduction) throw new Error(`${name} must be set in production`);
  return devDefault;
}

module.exports = {
  isProduction,
  port: Number(process.env.PORT) || 3000,

  databaseUrl: process.env.DATABASE_URL || "",
  dbPoolSize: Number(process.env.DB_POOL_SIZE || 10),
  localDataDir: process.env.LOCAL_DATA_DIR || ".data/pglite",
  backupsDir: process.env.BACKUPS_DIR || ".data/backups",
  backupS3: {
    endpoint: process.env.BACKUP_S3_ENDPOINT || "",
    region: process.env.BACKUP_S3_REGION || "auto",
    bucket: process.env.BACKUP_S3_BUCKET || "",
    accessKeyId: process.env.BACKUP_S3_ACCESS_KEY_ID || "",
    secretAccessKey: process.env.BACKUP_S3_SECRET_ACCESS_KEY || "",
    pathStyle: process.env.BACKUP_S3_PATH_STYLE === "true",
  },
  pgDump: process.env.PG_DUMP || "pg_dump",

  uploadsDir: process.env.UPLOADS_DIR || ".data/uploads",
  storage: process.env.STORAGE || "local",
  s3: {
    endpoint: process.env.S3_ENDPOINT || "",
    region: process.env.S3_REGION || "auto",
    bucket: process.env.S3_BUCKET || "",
    accessKeyId: process.env.S3_ACCESS_KEY_ID || "",
    secretAccessKey: process.env.S3_SECRET_ACCESS_KEY || "",
    pathStyle: process.env.S3_PATH_STYLE === "true",
  },
  maxUploadMb: Number(process.env.MAX_UPLOAD_MB || 10),
  maxVideoMb: Number(process.env.MAX_VIDEO_MB || 50),

  jwt: {
    accessSecret: secret("JWT_ACCESS_SECRET", "dev-access-secret"),
    refreshSecret: secret("JWT_REFRESH_SECRET", "dev-refresh-secret"),
    accessTtl: "15m",
    refreshTtlDays: 30,
  },

  webDir: process.env.WEB_DIR || require("path").join(__dirname, "../../build/web"),

  redisUrl: process.env.REDIS_URL || "",
  operatorName: process.env.OPERATOR_NAME || "the Madrasa team",
  contactEmail: process.env.CONTACT_EMAIL || "privacy@madrasa.iq",
  policyUpdated: process.env.POLICY_UPDATED || "2026-11-09",
  firebaseServiceAccountFile: process.env.FIREBASE_SERVICE_ACCOUNT_FILE || "",
  runWorker: (process.env.RUN_WORKER ?? "true") === "true",
  timeZone: process.env.TIME_ZONE || "Asia/Baghdad",

  seedDemoData: (process.env.SEED_DEMO_DATA ?? (isProduction ? "false" : "true")) === "true",
  demoMode: process.env.DEMO_MODE === "true",
  demoLanguage: process.env.DEMO_LANGUAGE || process.env.DEFAULT_LANGUAGE || "ar",
  demoPassword: process.env.DEMO_PASSWORD || "demo1234",

  corsOrigins: (process.env.CORS_ORIGINS || "").split(",").map((o) => o.trim()).filter(Boolean),
  cspReportOnly: process.env.CSP_REPORT_ONLY === "true",
  trustProxy: Number(process.env.TRUST_PROXY ?? (isProduction ? 1 : 0)),
  rateLimitsOff: process.env.RATE_LIMITS === "off",
  bcryptCost: Number(process.env.BCRYPT_COST || 12),
};

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
  if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
    problems.push("VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY must be set (npx web-push generate-vapid-keys)");
  }
  if (problems.length) {
    throw new Error(`Unsafe production settings:\n  - ${problems.join("\n  - ")}`);
  }
}

module.exports.checkProductionSettings = checkProductionSettings;
