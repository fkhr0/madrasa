// Uploading and downloading files (homework, worksheets).
//
//   POST /files  (body = the bytes, header X-File-Name)  -> { id, name, mime, size }
//   GET  /files/:id/link                                 -> { url }
//   GET  /files/:id/download?t=...                         -> the file
//
// Downloads use a short-lived link instead of the Authorization header, so
// the phone's browser can open the file directly.
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

/** How long a download link works. */
const LINK_TTL = "10m";

router.post(
  "/",
  requireAuth,
  uploadLimit,
  express.raw({ type: () => true, limit: `${Math.max(config.maxUploadMb, config.maxVideoMb)}mb` }),
  async (req, res) => {
    // express.raw gives bytes; anything else (no body) is an empty upload.
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
    // Our type for it, never the one the uploader sent.
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

  // Photos, PDFs and media open in the browser; everything else downloads.
  // Older files are judged by their name again, not by what was stored.
  const type = typeOf(file.name);
  const inline = type?.inline === true;
  res.setHeader("Content-Type", type?.mime ?? "application/octet-stream");
  res.setHeader(
    "Content-Disposition",
    `${inline ? "inline" : "attachment"}; filename*=UTF-8''${encodeURIComponent(file.name)}`,
  );
  res.setHeader("X-Content-Type-Options", "nosniff");
  // The app (another origin while developing) may show the photo.
  res.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  if (!inline) res.setHeader("Content-Security-Policy", "sandbox; default-src 'none'");
  res.setHeader("Cache-Control", "private, max-age=600");
  await storage.send(file.id, res, req.get("Range"));
});

/** Keeps the name readable but safe in a header: no paths, no control chars. */
function cleanName(name) {
  const base = name.split(/[\\/]/).pop().replace(/[\u0000-\u001f"]/g, "").trim();
  return base.slice(0, 120) || "file";
}

module.exports = router;
