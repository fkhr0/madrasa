// Runs the background jobs on their own (online: a separate service next to the
// API, both pointing at the same database and Redis).
const config = require("./config");
const { connect, close } = require("./db/database");
const { registerJobs } = require("./jobs");
const { startJobs, stopJobs } = require("./jobs/queue");

async function main() {
  config.checkProductionSettings();
  if (!config.redisUrl) {
    console.error("The worker needs REDIS_URL (BullMQ). Without Redis, the API runs the jobs itself.");
    process.exit(1);
  }
  await connect();
  registerJobs();
  await startJobs({ worker: true });
  console.log("Worker running. Ctrl+C to stop.");

  const stop = async () => {
    await stopJobs();
    await require("./common/redis").closeRedis();
    await close();
    process.exit(0);
  };
  process.on("SIGINT", stop);
  process.on("SIGTERM", stop);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
