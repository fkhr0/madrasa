const { test, before, after } = require("node:test");
const assert = require("node:assert/strict");
const { startTestApp, signIn, close, request } = require("./helpers");
const config = require("../src/config");

let app;
const as = {};
before(async () => {
  app = await startTestApp();
  for (const [name, id] of [["admin", "ADM-2020-0001"], ["ahmed", "TCH-2019-0031"]]) {
    as[name] = { Authorization: `Bearer ${(await signIn(app, id)).accessToken}` };
  }
});
after(close);

const upload = (name, bytes) =>
  request(app)
    .post("/files")
    .set(as.ahmed)
    .set("Content-Type", "text/html") // ignored: the server decides the type
    .set("X-File-Name", encodeURIComponent(name))
    .send(Buffer.from(bytes));

test("five wrong passwords lock the ID for 15 minutes, and the office sees it", async () => {
  const wrong = { schoolId: "TCH-2019-0041", password: "guess" };
  for (let i = 0; i < 5; i++) await request(app).post("/auth/login").send(wrong).expect(401);

  // Even the right password waits now.
  const locked = await request(app)
    .post("/auth/login")
    .send({ schoolId: "tch-2019-0041", password: config.demoPassword })
    .expect(429);
  assert.match(locked.body.error, /Try again in 15 minutes/);

  const { items } = (await request(app).get("/activity?kind=security").set(as.admin).expect(200)).body;
  assert.equal(items.length, 1);
  assert.match(items[0].summary, /locked out for 15 minutes after 5 wrong passwords/);
});

test("a right password clears earlier mistakes", async () => {
  const wrong = { schoolId: "STU-2026-0142", password: "guess" };
  for (let i = 0; i < 4; i++) await request(app).post("/auth/login").send(wrong).expect(401);
  await signIn(app, "STU-2026-0142");
  for (let i = 0; i < 4; i++) await request(app).post("/auth/login").send(wrong).expect(401);
  await signIn(app, "STU-2026-0142");
});

test("only allowed kinds of files, and only when the content matches the name", async () => {
  await upload("virus.exe", "MZ...").expect(415);
  await upload("page.html", "<script>alert(1)</script>").expect(415);
  await upload("page.svg", "<svg onload=alert(1)>").expect(415);
  // A web page dressed up as a photo.
  const fake = await upload("photo.jpg", "<html><script>alert(1)</script>").expect(415);
  assert.match(fake.body.error, /doesn't match its name/);

  const pdf = (await upload("Chapter 4.pdf", "%PDF-1.4 demo").expect(201)).body;
  assert.equal(pdf.mime, "application/pdf");
});

test("downloads: our type, PDFs open, other files only download", async () => {
  const open = async (file) => {
    const { url } = (await request(app).get(`/files/${file.id}/link`).set(as.ahmed).expect(200)).body;
    return request(app).get(url).expect(200);
  };

  const pdf = await open((await upload("Plan.pdf", "%PDF-1.4 x").expect(201)).body);
  assert.equal(pdf.headers["content-type"], "application/pdf");
  assert.match(pdf.headers["content-disposition"], /^inline;/);
  assert.equal(pdf.headers["x-content-type-options"], "nosniff");

  const sheet = await open((await upload("Marks.csv", "name,mark\nZainab,95").expect(201)).body);
  assert.match(sheet.headers["content-disposition"], /^attachment;/);
  assert.match(sheet.headers["content-security-policy"], /sandbox/);
});

test("security headers on every answer", async () => {
  const res = await request(app).get("/health").expect(200);
  assert.match(res.headers["content-security-policy"], /frame-ancestors 'none'/);
  assert.equal(res.headers["x-content-type-options"], "nosniff");
  assert.equal(res.headers["x-powered-by"], undefined);
});

test("other websites can't call the API from a browser", async () => {
  const stranger = await request(app).get("/health").set("Origin", "https://evil.example");
  assert.equal(stranger.headers["access-control-allow-origin"], undefined);

  // While developing, the web app on localhost works.
  const local = await request(app).get("/health").set("Origin", "http://localhost:5173");
  assert.equal(local.headers["access-control-allow-origin"], "http://localhost:5173");
});

test("the server refuses to start online with unsafe settings", () => {
  assert.throws(
    () => config.checkProductionSettings({ isProduction: true, databaseUrl: "", seedDemoData: true }),
    /JWT_ACCESS_SECRET[\s\S]*DATABASE_URL[\s\S]*SEED_DEMO_DATA/,
  );
  // Fine on this PC.
  config.checkProductionSettings({ isProduction: false });
});

test("photos are shrunk, turned upright, and lose their hidden GPS place", async () => {
  const sharp = require("sharp");
  // A 4000×3000 phone photo with noise (hard to compress) and its place in EXIF.
  const width = 4000, height = 3000;
  const noise = Buffer.alloc(width * height * 3);
  for (let i = 0; i < noise.length; i++) noise[i] = (i * 7919) % 251;
  const photo = await sharp(noise, { raw: { width, height, channels: 3 } })
    .withExif({ IFD0: { Make: "Phone" }, IFD3: { GPSLatitudeRef: "N", GPSLatitude: "33/1 18/1 0/1" } })
    .jpeg({ quality: 95 })
    .toBuffer();
  assert.ok((await sharp(photo).metadata()).exif, "the test photo has EXIF");

  const file = (await upload("Board.jpg", photo).expect(201)).body;
  assert.ok(file.size < photo.length / 2, `${file.size} < ${photo.length / 2}`);

  const { url } = (await request(app).get(`/files/${file.id}/link`).set(as.ahmed).expect(200)).body;
  const saved = (await request(app).get(url).buffer(true).parse(binary).expect(200)).body;
  const info = await sharp(saved).metadata();
  assert.equal(Math.max(info.width, info.height), 1600);
  assert.equal(info.exif, undefined);

  // Not really a photo inside: refused, not saved.
  const broken = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.from("not a photo")]);
  await upload("broken.jpg", broken).expect(415);
});

/** supertest: keep the answer as bytes. */
function binary(res, done) {
  const parts = [];
  res.on("data", (c) => parts.push(c));
  res.on("end", () => done(null, Buffer.concat(parts)));
}

test("answers carry a version tag; unchanged ones are a tiny 304, never stored by proxies", async () => {
  const first = await request(app).get("/academic-year").set(as.ahmed).set("Accept-Encoding", "gzip").expect(200);
  assert.ok(first.headers.etag);
  assert.equal(first.headers["cache-control"], "private, no-cache");

  const again = await request(app)
    .get("/academic-year")
    .set(as.ahmed)
    .set("Accept-Encoding", "gzip")
    .set("If-None-Match", first.headers.etag)
    .expect(304);
  assert.equal(again.text, "");
});

test("a file's download link can't be used to sign in, nor a sign-in as a link", async () => {
  const file = (await upload("Plan.pdf", "%PDF-1.4 x").expect(201)).body;
  const { url } = (await request(app).get(`/files/${file.id}/link`).set(as.ahmed).expect(200)).body;
  const linkToken = new URL(url, "http://x").searchParams.get("t");

  await request(app).get("/me").set({ Authorization: `Bearer ${linkToken}` }).expect(401);
  const signIn = as.ahmed.Authorization.slice(7);
  await request(app).get(`/files/${file.id}/download?t=${signIn}`).expect(401);
});

test("a forgotten password reaches the school office, without telling who exists", async () => {
  const known = await request(app).post("/auth/password-reset").send({ emailOrPhone: "stu-2026-0142" }).expect(202);
  const unknown = await request(app).post("/auth/password-reset").send({ emailOrPhone: "STU-1999-0000" }).expect(202);
  assert.deepEqual(known.body, unknown.body);

  const admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };
  const told = (await request(app).get("/notifications").set(admin)).body;
  assert.ok(told.some((n) => n.title === "Zainab Haider forgot their password"));
});

test("one school's office can't reach another school's people", async () => {
  const { query } = require("../src/db/database");
  const other = (await query("SELECT id FROM users WHERE institution_id <> 'inst-001' AND role = 'student' LIMIT 1"))[0];
  const admin = { Authorization: `Bearer ${(await signIn(app, "ADM-2020-0001")).accessToken}` };
  await request(app).get(`/people/${other.id}`).set(admin).expect(404);
  await request(app).get(`/timetable/people/${other.id}/week`).set(admin).expect(404);
  await request(app).get(`/attendance/students/${other.id}/days`).set(admin).expect((r) => assert.ok([403, 404].includes(r.status)));
});

test("metrics for Prometheus: requests, timings, sign-ins", async () => {
  await request(app).get("/academic-year").set(as.ahmed).expect(200);
  const page = (await request(app).get("/metrics").expect(200)).text;
  assert.match(page, /http_requests_total\{[^}]*route="\/academic-year"[^}]*status="200"/);
  assert.match(page, /http_request_duration_seconds_bucket/);
  assert.match(page, /sign_ins_total\{[^}]*result="ok"/);
  assert.match(page, /nodejs_heap_size_used_bytes/);
});
