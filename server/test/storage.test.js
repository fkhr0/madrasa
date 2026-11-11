// Files in an S3 bucket (Cloudflare R2, MinIO...), as with several servers.
// A small S3 server in memory stands in for the bucket.
const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { startFakeS3 } = require("./fake-s3");
const { startTestApp, signIn, close, request } = require("./helpers");
const config = require("../src/config");
const { query } = require("../src/db/database");
const { cleanUp } = require("../src/jobs/upkeep");

let app, bucketServer;
const as = {};
before(async () => {
  bucketServer = await startFakeS3();
  const { port } = bucketServer;
  Object.assign(config, { storage: "s3" });
  Object.assign(config.s3, {
    endpoint: `http://127.0.0.1:${port}`,
    region: "us-east-1",
    bucket: "school",
    accessKeyId: "test",
    secretAccessKey: "test",
    pathStyle: true,
  });

  app = await startTestApp();
  as.ahmed = { Authorization: `Bearer ${(await signIn(app, "TCH-2019-0031")).accessToken}` };
});
after(async () => {
  await close();
  await bucketServer.close();
});

const upload = (name, bytes) =>
  request(app).post("/files").set(as.ahmed).set("X-File-Name", encodeURIComponent(name)).send(bytes);
const linkOf = async (id) => (await request(app).get(`/files/${id}/link`).set(as.ahmed).expect(200)).body.url;
/** supertest: keep the answer as bytes. */
const binary = (res, done) => {
  const parts = [];
  res.on("data", (c) => parts.push(c));
  res.on("end", () => done(null, Buffer.concat(parts)));
};

test("a file goes to the bucket and comes back with our safety headers", async () => {
  const text = Buffer.from("name,mark\nZainab,95\nAli,88\n");
  const file = (await upload("Marks.csv", text).expect(201)).body;

  // Not on this server's disk.
  assert.equal(fs.existsSync(path.join(config.uploadsDir, file.id)), false);

  const res = await request(app).get(await linkOf(file.id)).buffer(true).parse(binary).expect(200);
  assert.deepEqual(res.body, text);
  assert.match(res.headers["content-disposition"], /^attachment;/);
  assert.match(res.headers["content-security-policy"], /sandbox/);
});

test("videos can seek: a part of the file (Range)", async () => {
  const bytes = Buffer.from("%PDF-1.4 0123456789abcdef");
  const file = (await upload("Part.pdf", bytes).expect(201)).body;

  const res = await request(app)
    .get(await linkOf(file.id))
    .set("Range", "bytes=9-18")
    .buffer(true)
    .parse(binary)
    .expect(206);
  assert.equal(res.body.toString(), "0123456789");
  assert.equal(res.headers["content-range"], `bytes 9-18/${bytes.length}`);
});

test("files nobody uses are removed from the bucket too", async () => {
  const file = (await upload("forgotten.txt", Buffer.from("x")).expect(201)).body;
  await query("UPDATE files SET created_at = now() - interval '2 days' WHERE id = $1", [file.id]);
  const url = await linkOf(file.id);

  await cleanUp();

  const { S3Client, HeadObjectCommand } = require("@aws-sdk/client-s3");
  const s3 = new S3Client({
    endpoint: config.s3.endpoint,
    region: config.s3.region,
    credentials: { accessKeyId: "test", secretAccessKey: "test" },
    forcePathStyle: true,
  });
  await assert.rejects(s3.send(new HeadObjectCommand({ Bucket: "school", Key: `uploads/${file.id}` })));
  await request(app).get(url).expect(404);
});

test("nightly: the dump and new uploads are copied off the server", async () => {
  const offsite = require("../src/jobs/offsite");
  Object.assign(config, { storage: "local" });
  Object.assign(config.backupS3, { ...config.s3, bucket: "school" });
  const dump = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "school-dump-")), "school-2026-11-09.dump");
  fs.writeFileSync(dump, "a database");
  fs.mkdirSync(config.uploadsDir, { recursive: true });
  fs.writeFileSync(path.join(config.uploadsDir, "file-a"), "x");

  assert.equal(await offsite.sendDump(dump), "database/school-2026-11-09.dump");
  assert.ok((await offsite.sendNewUploads()) >= 1);
  assert.equal(await offsite.sendNewUploads(), 0); // each file only once
  Object.assign(config, { storage: "s3" });
});
