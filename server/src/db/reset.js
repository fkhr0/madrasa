// npm run db:reset, deletes the LOCAL database folder so the next start
// creates it again with fresh demo data. Never touches an online database.
const fs = require("fs");
const config = require("../config");

if (config.databaseUrl) {
  console.error("DATABASE_URL is set: reset only works on the local database.");
  process.exit(1);
}

fs.rmSync(config.localDataDir, { recursive: true, force: true });
console.log(`Deleted ${config.localDataDir}. Start the server to rebuild it.`);
