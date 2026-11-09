// Where the bytes of uploaded files live.
const fs = require("fs");
const path = require("path");
const config = require("../../config");
const { t } = require("../../i18n");

const local = {
  async save(id, bytes) {
    await fs.promises.mkdir(config.uploadsDir, { recursive: true });
    await fs.promises.writeFile(path.join(config.uploadsDir, id), bytes);
  },

  /** Sends the file as the answer (headers already set by the route). */
  send(id, res) {
    res.sendFile(path.resolve(config.uploadsDir, id), (err) => {
      if (err && !res.headersSent) res.status(404).json({ error: t("File not found.") });
    });
  },

  async remove(id) {
    await fs.promises.rm(path.join(config.uploadsDir, id), { force: true });
  },
};

let client = null;
/** The S3 connection, made the first time it is needed. */
function s3() {
  if (!client) {
    const { S3Client } = require("@aws-sdk/client-s3");
    client = new S3Client({
      endpoint: config.s3.endpoint || undefined,
      region: config.s3.region,
      credentials: { accessKeyId: config.s3.accessKeyId, secretAccessKey: config.s3.secretAccessKey },
      // MinIO and test servers use bucket/key paths instead of bucket.host names.
      forcePathStyle: config.s3.pathStyle,
    });
  }
  return client;
}

const bucket = {
  async save(id, bytes, mime) {
    const { PutObjectCommand } = require("@aws-sdk/client-s3");
    await s3().send(
      new PutObjectCommand({ Bucket: config.s3.bucket, Key: keyOf(id), Body: bytes, ContentType: mime }),
    );
  },

  /**
   * Streams the file through this server, so our safety headers stay on it
   * and the bucket stays private. Passes "Range" on, so videos can seek.
   */
  async send(id, res, range) {
    const { GetObjectCommand } = require("@aws-sdk/client-s3");
    let object;
    try {
      object = await s3().send(
        new GetObjectCommand({ Bucket: config.s3.bucket, Key: keyOf(id), Range: range }),
      );
    } catch (e) {
      const missing = e.name === "NoSuchKey" || e.$metadata?.httpStatusCode === 404;
      res.status(missing ? 404 : 502).json({ error: t(missing ? "File not found." : "Storage error.") });
      return;
    }
    if (object.ContentRange) {
      res.status(206).setHeader("Content-Range", object.ContentRange);
    }
    res.setHeader("Accept-Ranges", "bytes");
    if (object.ContentLength != null) res.setHeader("Content-Length", object.ContentLength);
    object.Body.on("error", () => res.destroy());
    object.Body.pipe(res);
  },

  async remove(id) {
    const { DeleteObjectCommand } = require("@aws-sdk/client-s3");
    await s3().send(new DeleteObjectCommand({ Bucket: config.s3.bucket, Key: keyOf(id) }));
  },
};

/** uploads/<id>: room for other folders in the same bucket later (backups). */
const keyOf = (id) => `uploads/${id}`;

/** The storage in use (read each time, so tests can switch it). */
const storage = () => (config.storage === "s3" ? bucket : local);

module.exports = {
  save: (id, bytes, mime) => storage().save(id, bytes, mime),
  send: (id, res, range) => storage().send(id, res, range),
  remove: (id) => storage().remove(id),
};
