// Copies of the backups away from the server (a dead server must not take its
// backups with it): the nightly database dump and uploaded files go to an
// S3-compatible bucket: AWS S3, Oracle Object Storage, Cloudflare R2.
const fs = require("fs");
const path = require("path");
const config = require("../config");

/** Database dumps kept in the bucket (one a night). */
const KEEP_DUMPS = 14;

let client = null;
function s3() {
  if (!client) {
    const { S3Client } = require("@aws-sdk/client-s3");
    const b = config.backupS3;
    client = new S3Client({
      endpoint: b.endpoint || undefined,
      region: b.region,
      // No keys: the server's own AWS role.
      credentials: b.accessKeyId
        ? { accessKeyId: b.accessKeyId, secretAccessKey: b.secretAccessKey }
        : undefined,
      forcePathStyle: b.pathStyle,
    });
  }
  return client;
}

const enabled = () => Boolean(config.backupS3.bucket);

/** Uploads tonight's dump and keeps the last [KEEP_DUMPS]. */
async function sendDump(file) {
  if (!enabled() || !file) return null;
  const { PutObjectCommand, ListObjectsV2Command, DeleteObjectCommand } = require("@aws-sdk/client-s3");
  const Bucket = config.backupS3.bucket;
  const Key = `database/${path.basename(file)}`;
  await s3().send(new PutObjectCommand({ Bucket, Key, Body: fs.createReadStream(file) }));

  const listed = await s3().send(new ListObjectsV2Command({ Bucket, Prefix: "database/" }));
  const old = (listed.Contents ?? [])
    .map((o) => o.Key)
    .sort()
    .slice(0, -KEEP_DUMPS);
  for (const key of old) await s3().send(new DeleteObjectCommand({ Bucket, Key: key }));
  return Key;
}

/**
 * Uploaded files not in the bucket yet (files never change, so each is
 * copied once). Only with STORAGE=local: a bucket storage is off-site already.
 */
async function sendNewUploads() {
  if (!enabled() || config.storage !== "local") return 0;
  if (!fs.existsSync(config.uploadsDir)) return 0;
  const { PutObjectCommand, ListObjectsV2Command } = require("@aws-sdk/client-s3");
  const Bucket = config.backupS3.bucket;

  const there = new Set();
  let token;
  do {
    const page = await s3().send(
      new ListObjectsV2Command({ Bucket, Prefix: "uploads/", ContinuationToken: token }),
    );
    for (const o of page.Contents ?? []) there.add(o.Key);
    token = page.NextContinuationToken;
  } while (token);

  let sent = 0;
  for (const name of await fs.promises.readdir(config.uploadsDir)) {
    const Key = `uploads/${name}`;
    if (there.has(Key)) continue;
    await s3().send(
      new PutObjectCommand({ Bucket, Key, Body: fs.createReadStream(path.join(config.uploadsDir, name)) }),
    );
    sent++;
  }
  return sent;
}

module.exports = { sendDump, sendNewUploads, KEEP_DUMPS };
