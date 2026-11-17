const { CronExpressionParser } = require("cron-parser");
const config = require("../config");

const QUEUE = "school";

const handlers = new Map();
const schedules = new Map();

let engine = null;

function defineJob(name, handler) {
  handlers.set(name, handler);
}

function schedule(name, pattern) {
  schedules.set(name, pattern);
}

async function enqueue(name, data = {}) {
  if (!engine) return run(name, data);
  return engine.enqueue(name, data);
}

async function run(name, data) {
  const handler = handlers.get(name);
  if (!handler) throw new Error(`Unknown job: ${name}`);
  return handler(data);
}

async function startJobs({ worker = config.runWorker } = {}) {
  if (engine) return engine;
  engine = config.redisUrl ? await bullEngine(worker) : timerEngine(worker);
  return engine;
}

async function stopJobs() {
  await engine?.stop();
  engine = null;
}

async function bullEngine(worker) {
  const { Queue, Worker } = require("bullmq");
  const IORedis = require("ioredis");
  const connection = new IORedis(config.redisUrl, { maxRetriesPerRequest: null });
  connection.on("error", (e) => console.warn(`Redis: ${e.message}`));

  const queue = new Queue(QUEUE, {
    connection,
    defaultJobOptions: {
      attempts: 3,
      backoff: { type: "exponential", delay: 30_000 },
      removeOnComplete: { count: 200 },
      removeOnFail: { count: 500 },
    },
  });

  for (const [name, pattern] of schedules) {
    await queue.upsertJobScheduler(name, { pattern, tz: config.timeZone }, { name });
  }

  let runner = null;
  if (worker) {
    runner = new Worker(QUEUE, (job) => run(job.name, job.data), {
      connection: connection.duplicate({ maxRetriesPerRequest: null }),
      concurrency: 4,
    });
    runner.on("failed", (job, err) =>
      console.warn(`Job ${job?.name} failed (try ${job?.attemptsMade}): ${err.message}`),
    );
  }
  console.log(`Background jobs: BullMQ on Redis${worker ? "" : " (queue only)"}`);

  return {
    name: "bullmq",
    enqueue: (name, data) => queue.add(name, data),
    async stop() {
      await runner?.close();
      await queue.close();
      await connection.quit();
    },
  };
}

function timerEngine(worker) {
  const timers = new Set();
  const safely = (name, data) =>
    run(name, data).catch((e) => console.warn(`Job ${name} failed: ${e.message}`));

  if (worker) {
    for (const [name, pattern] of schedules) {
      const next = () => {
        const at = CronExpressionParser.parse(pattern, { tz: config.timeZone }).next().toDate();
        const timer = setTimeout(async () => {
          timers.delete(timer);
          await safely(name, {});
          next();
        }, Math.max(1000, at - Date.now()));
        timer.unref();
        timers.add(timer);
      };
      next();
    }
  }
  if (!process.env.NODE_TEST_CONTEXT) {
    console.log("Background jobs: built-in timer (set REDIS_URL to use BullMQ)");
  }

  return {
    name: "timer",
    enqueue: (name, data) => {
      setImmediate(() => safely(name, data));
    },
    async stop() {
      for (const t of timers) clearTimeout(t);
      timers.clear();
    },
  };
}

module.exports = { defineJob, schedule, enqueue, run, startJobs, stopJobs };
