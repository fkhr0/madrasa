const config = require("../config");

let engine = null;

async function connect({ dataDir } = {}) {
  if (engine) return engine;

  if (config.databaseUrl && !dataDir) {
    const { Pool, types } = require("pg");
    readValuesLikePglite(types);
    const pool = new Pool({ connectionString: config.databaseUrl, max: config.dbPoolSize });
    engine = {
      name: "postgres",
      query: (text, params) => pool.query(text, params),
      async transaction(work) {
        const client = await pool.connect();
        try {
          await client.query("BEGIN");
          const result = await work(helpers((t, p) => client.query(t, p)));
          await client.query("COMMIT");
          return result;
        } catch (err) {
          await client.query("ROLLBACK");
          throw err;
        } finally {
          client.release();
        }
      },
      exec: (text) => pool.query(text),
      async withLock(name, work) {
        const client = await pool.connect();
        try {
          await client.query("BEGIN");
          await client.query("SELECT pg_advisory_xact_lock(hashtext($1))", [name]);
          const result = await work();
          await client.query("COMMIT");
          return result;
        } catch (err) {
          await client.query("ROLLBACK").catch(() => {});
          throw err;
        } finally {
          client.release();
        }
      },
      close: () => pool.end(),
    };
  } else {
    const { PGlite } = require("@electric-sql/pglite");
    const folder = dataDir || config.localDataDir;
    if (!folder.includes("://")) {
      require("fs").mkdirSync(require("path").dirname(folder), {
        recursive: true,
      });
    }
    const db = await PGlite.create(folder);
    engine = {
      name: "pglite",
      query: (text, params) => db.query(text, params),
      transaction: (work) =>
        db.transaction((tx) => work(helpers((t, p) => tx.query(t, p)))),
      exec: (text) => db.exec(text),
      withLock: (_name, work) => work(),
      dump: () => db.dumpDataDir("gzip"),
      close: () => db.close(),
    };
  }

  return engine;
}

function readValuesLikePglite(types) {
  const INT8 = 20, INT8_ARRAY = 1016, DATE = 1082, DATE_ARRAY = 1182, TEXT_ARRAY = 1009;
  const asDate = (v) => (v === null ? null : new Date(`${v}T00:00:00Z`));
  const textArray = types.getTypeParser(TEXT_ARRAY);
  types.setTypeParser(INT8, Number);
  types.setTypeParser(INT8_ARRAY, (v) => textArray(v).map((x) => (x === null ? null : Number(x))));
  types.setTypeParser(DATE, asDate);
  types.setTypeParser(DATE_ARRAY, (v) => textArray(v).map(asDate));
}

function helpers(run) {
  const txQuery = async (text, params = []) => (await run(text, params)).rows;
  return {
    query: txQuery,
    queryOne: async (text, params = []) =>
      (await txQuery(text, params))[0] ?? null,
  };
}

function db() {
  if (!engine) throw new Error("Database not connected: call connect() first");
  return engine;
}

async function query(text, params = []) {
  return (await db().query(text, params)).rows;
}

async function queryOne(text, params = []) {
  const rows = await query(text, params);
  return rows[0] ?? null;
}

function transaction(work) {
  return db().transaction(work);
}

function withLock(name, work) {
  return db().withLock(name, work);
}

async function close() {
  if (!engine) return;
  await engine.close();
  engine = null;
}

module.exports = { connect, query, queryOne, transaction, withLock, close, db };
