// A tiny S3 server in memory for the storage tests: the calls the app makes
// (put, get with Range, head, delete, list), path style (/bucket/key).
const http = require("http");

/** The body without aws-chunked framing ("size\r\ndata\r\n...0\r\ntrailers"). */
function unchunk(raw) {
  const parts = [];
  let at = 0;
  for (;;) {
    const end = raw.indexOf("\r\n", at);
    const size = parseInt(raw.subarray(at, end).toString().split(";")[0], 16);
    if (!size) break;
    parts.push(raw.subarray(end + 2, end + 2 + size));
    at = end + 2 + size + 2;
  }
  return Buffer.concat(parts);
}

const xml = (body) => `<?xml version="1.0" encoding="UTF-8"?>${body}`;
const escape = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function notFound(req, res) {
  res.writeHead(404, { "Content-Type": "application/xml" });
  if (req.method === "HEAD") return res.end();
  res.end(xml("<Error><Code>NoSuchKey</Code><Message>Not found</Message></Error>"));
}

async function startFakeS3() {
  const objects = new Map(); // "bucket/key" -> Buffer

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, "http://s3");
    const [bucket, ...rest] = url.pathname.slice(1).split("/");
    const key = decodeURIComponent(rest.join("/"));
    const name = `${bucket}/${key}`;

    const chunks = [];
    for await (const c of req) chunks.push(c);
    let body = Buffer.concat(chunks);

    if (req.method === "PUT") {
      const chunked =
        String(req.headers["content-encoding"] || "").includes("aws-chunked") ||
        String(req.headers["x-amz-content-sha256"] || "").startsWith("STREAMING");
      if (chunked) body = unchunk(body);
      objects.set(name, body);
      res.writeHead(200, { ETag: '"fake"' });
      return res.end();
    }

    if (req.method === "GET" && !key) {
      const prefix = url.searchParams.get("prefix") || "";
      const keys = [...objects.keys()]
        .filter((k) => k.startsWith(`${bucket}/${prefix}`))
        .map((k) => k.slice(bucket.length + 1))
        .sort();
      const contents = keys
        .map((k) => `<Contents><Key>${escape(k)}</Key><Size>${objects.get(`${bucket}/${k}`).length}</Size></Contents>`)
        .join("");
      res.writeHead(200, { "Content-Type": "application/xml" });
      return res.end(
        xml(`<ListBucketResult><Name>${bucket}</Name><Prefix>${escape(prefix)}</Prefix>` +
          `<KeyCount>${keys.length}</KeyCount><IsTruncated>false</IsTruncated>${contents}</ListBucketResult>`),
      );
    }

    if (req.method === "GET" || req.method === "HEAD") {
      const object = objects.get(name);
      if (!object) return notFound(req, res);
      const range = /^bytes=(\d+)-(\d*)$/.exec(req.headers.range || "");
      if (range) {
        const from = Number(range[1]);
        const to = range[2] ? Math.min(Number(range[2]), object.length - 1) : object.length - 1;
        res.writeHead(206, {
          "Content-Range": `bytes ${from}-${to}/${object.length}`,
          "Content-Length": to - from + 1,
        });
        return res.end(req.method === "HEAD" ? undefined : object.subarray(from, to + 1));
      }
      res.writeHead(200, { "Content-Length": object.length });
      return res.end(req.method === "HEAD" ? undefined : object);
    }

    if (req.method === "DELETE") {
      objects.delete(name);
      res.writeHead(204);
      return res.end();
    }

    res.writeHead(400);
    res.end();
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  return {
    port: server.address().port,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

module.exports = { startFakeS3 };
