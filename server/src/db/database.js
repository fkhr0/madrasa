// The one door to PostgreSQL.
const config = require("../config");

let engine = null;

/**
 * Opens the database. `dataDir` overrides the PGlite folder
 * ("memory://" gives an empty in-memory database, used by the tests).
 */
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
        // A PostgreSQL "advisory lock": a named lock that other servers
        // wait on. Held by this connection until it unlocks.
        const client = await pool.connect();
        try {
          await client.query("SELECT pg_advisory_lock(hashtext($1))", [name]);
          return await work();
        } finally {
          await client.query("SELECT pg_advisory_unlock(hashtext($1))", [name]).catch(() => {});
          client.release();
        }
      },
      close: () => pool.end(),
    };
  } else {
    const { PGlite } = require("@electric-sql/pglite");
    const folder = dataDir || config.localDataDir;
    // PGlite creates its own folder but not the ones above it (.data/).
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
      // Only one process can open a PGlite folder: nothing to wait for.
      withLock: (_name, work) => work(),
      // The whole database as one compressed file, for the nightly backup.
      dump: () => db.dumpDataDir("gzip"),
      close: () => db.close(),
    };
  }

  return engine;
}

/** `pg` reads a few types differently from PGlite; make it read them the same, so the code behaves the same on this PC and online. */
function readValuesLikePglite(types) {
  const INT8 = 20, INT8_ARRAY = 1016, DATE = 1082, DATE_ARRAY = 1182, TEXT_ARRAY = 1009;
  const asDate = (v) => (v === null ? null : new Date(`${v}T00:00:00Z`));
  const textArray = types.getTypeParser(TEXT_ARRAY);
  types.setTypeParser(INT8, Number);
  types.setTypeParser(INT8_ARRAY, (v) => textArray(v).map((x) => (x === null ? null : Number(x))));
  types.setTypeParser(DATE, asDate);
  types.setTypeParser(DATE_ARRAY, (v) => textArray(v).map(asDate));
}

/**
 * What a transaction gives its work function: the same query() and
 * queryOne() as this module, but running inside the transaction.
 */
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

/** Runs one statement. Returns the rows. */
async function query(text, params = []) {
  return (await db().query(text, params)).rows;
}

/** The first row, or null. */
async function queryOne(text, params = []) {
  const rows = await query(text, params);
  return rows[0] ?? null;
}

/**
 * Runs `work(tx)` in one transaction: all of it is saved, or none of it.
 * `tx` has query() and queryOne(), like this module.
 */
function transaction(work) {
  return db().transaction(work);
}

/**
 * Runs `work` while no other server runs work under the same name. Several
 * servers starting together: one brings the database up to date, the
 * others wait and then find nothing left to do.
 */
function withLock(name, work) {
  return db().withLock(name, work);
}

async function close() {
  if (!engine) return;
  await engine.close();
  engine = null;
}

module.exports = { connect, query, queryOne, transaction, withLock, close, db };
