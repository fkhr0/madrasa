const express = require("express");
const tokens = require("../auth/tokens");
const config = require("../../config");
const { HttpError } = require("../../common/http");
const { requireAuth } = require("../../common/auth-middleware");
const repo = require("./files.repository");
const storage = require("./storage");
const { typeOf, matches, ALLOWED } = require("./file-types");
const { shrinkImage } = require("./shrink-image");
const { uploadLimit } = require("../../common/security");

const router = express.Router();

const LINK_TTL = "10m";

router.post(
  "/",
  requireAuth,
  uploadLimit,
  express.raw({ type: () => true, limit: `${Math.max(config.maxUploadMb, config.maxVideoMb)}mb` }),
  async (req, res) => {
    const bytes = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
    if (bytes.length === 0) {
      throw new HttpError(400, "The file is empty.");
    }
    const name = cleanName(decodeURIComponent(req.get("X-File-Name") || "file"));
    const type = typeOf(name);
    if (!type) throw new HttpError(415, "This kind of file can't be uploaded. Allowed: {0}.", [ALLOWED]);
    if (!matches(type, bytes)) {
      throw new HttpError(415, "The file's content doesn't match its name.");
    }
    const mostMb = type.mime.startsWith("video/") ? config.maxVideoMb : config.maxUploadMb;
    if (bytes.length > mostMb * 1024 * 1024) {
      throw new HttpError(413, "{0} is too big. The most for this kind of file is {1} MB.", [name, mostMb]);
    }
    const mime = type.mime;
    const saved = await shrinkImage(bytes, mime);

    const file = await repo.insertFile(req.user, { name, mime, size: saved.length });
    await storage.save(file.id, saved, mime);
    res.status(201).json(file);
  },
);

router.get("/:id/link", requireAuth, async (req, res) => {
  const file = await repo.findFile(req.params.id);
  if (!file || !(await repo.canSee(req.user, file))) {
    throw new HttpError(404, "File not found.");
  }
  const token = tokens.signFileToken(file.id, LINK_TTL);
  res.json({ url: `/files/${file.id}/download?t=${token}` });
});

router.get("/:id/download", async (req, res) => {
  let payload;
  try {
    payload = tokens.verifyToken(req.query.t, "file");
  } catch {
    throw new HttpError(401, "This link has expired. Open the file again from the app.");
  }
  const file = await repo.findFile(req.params.id);
  if (!file || payload.file !== file.id) throw new HttpError(404, "File not found.");

  const type = typeOf(file.name);
  const inline = type?.inline === true;
  res.setHeader("Content-Type", type?.mime ?? "application/octet-stream");
  res.setHeader(
    "Content-Disposition",
    `${inline ? "inline" : "attachment"}; filename*=UTF-8''${encodeURIComponent(file.name)}`,
  );
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  if (!inline) res.setHeader("Content-Security-Policy", "sandbox; default-src 'none'");
  res.setHeader("Cache-Control", "private, max-age=600");
  await storage.send(file.id, res, req.get("Range"));
});

function cleanName(name) {
  const base = name.split(/[\\/]/).pop().replace(/[\u0000-\u001f"]/g, "").trim();
  return base.slice(0, 120) || "file";
}

module.exports = router;
