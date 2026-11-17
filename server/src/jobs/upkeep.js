const fs = require("fs");
const { execFile } = require("child_process");
const path = require("path");
const config = require("../config");
const { db, query } = require("../db/database");
const storage = require("../features/files/storage");

const KEEP_BACKUPS = 7;

async function cleanUp() {
  const sessions = await query(
    `DELETE FROM sessions
     WHERE expires_at < now() OR revoked_at < now() - interval '30 days'
     RETURNING id`,
  );
  const notifications = await query(
    "DELETE FROM notifications WHERE created_at < now() - interval '90 days' RETURNING id",
  );
  const reminders = await query(
    "DELETE FROM sent_reminders WHERE sent_at < now() - interval '60 days' RETURNING key",
  );

  const orphans = await query(
    `DELETE FROM files f
     WHERE f.created_at < now() - interval '1 day'
       AND NOT EXISTS (SELECT 1 FROM assignment_attachments a WHERE a.file_id = f.id)
       AND NOT EXISTS (SELECT 1 FROM submission_files s WHERE s.file_id = f.id)
       AND NOT EXISTS (SELECT 1 FROM resources r WHERE r.file_id = f.id)
     RETURNING f.id`,
  );
  for (const { id } of orphans) {
    await storage.remove(id).catch(() => {});
  }

  return {
    sessions: sessions.length,
    notifications: notifications.length,
    reminders: reminders.length,
    files: orphans.length,
  };
}

async function backUp(folder = config.backupsDir) {
  const engine = db();
  await fs.promises.mkdir(folder, { recursive: true });
  const day = new Date().toISOString().slice(0, 10);

  let file;
  if (engine.dump) {
    file = path.join(folder, `school-${day}.tar.gz`);
    const dump = await engine.dump();
    await fs.promises.writeFile(file, Buffer.from(await dump.arrayBuffer()));
  } else {
    file = path.join(folder, `school-${day}.dump`);
    await pgDump(file);
  }

  const old = (await fs.promises.readdir(folder))
    .filter((f) => /^school-\d{4}-\d{2}-\d{2}\.(tar\.gz|dump)$/.test(f))
    .sort()
    .slice(0, -KEEP_BACKUPS);
  for (const f of old) await fs.promises.rm(path.join(folder, f), { force: true });
  return file;
}

function pgDump(file) {
  const url = new URL(config.databaseUrl);
  const env = {
    ...process.env,
    PGHOST: url.hostname,
    PGPORT: url.port || "5432",
    PGUSER: decodeURIComponent(url.username),
    PGPASSWORD: decodeURIComponent(url.password),
    PGDATABASE: url.pathname.slice(1),
    PGSSLMODE: url.searchParams.get("sslmode") || "prefer",
  };
  return new Promise((resolve, reject) => {
    execFile(config.pgDump, ["--format=custom", "--no-owner", "--file", file], { env }, (err, _out, stderr) =>
      err ? reject(new Error(stderr.trim() || err.message)) : resolve(),
    );
  });
}

async function nightly() {
  const backup = await backUp().catch((e) => {
    console.warn(`Backup failed: ${e.message}`);
    return null;
  });
  const offsite = require("./offsite");
  const sentDump = await offsite.sendDump(backup).catch((e) => {
    console.warn(`Off-site backup failed: ${e.message}`);
    return null;
  });
  const sentUploads = await offsite.sendNewUploads().catch((e) => {
    console.warn(`Off-site copy of uploads failed: ${e.message}`);
    return 0;
  });
  const cleaned = await cleanUp();
  console.log(
    `Nightly upkeep: backup ${backup ?? "skipped"}, off-site ${sentDump ?? "off"}, ` +
      `${sentUploads} new uploads copied, removed ${JSON.stringify(cleaned)}`,
  );
  return { backup, offsite: sentDump, uploadsCopied: sentUploads, ...cleaned };
}

module.exports = { nightly, cleanUp, backUp };
