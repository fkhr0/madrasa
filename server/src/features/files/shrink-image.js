// Photos made smaller and safer before they are saved.
const sharp = require("sharp");
const { HttpError } = require("../../common/http");

const MAX_SIDE = 1600;
// A small file can unpack into a gigantic picture that fills the memory.
const MAX_PIXELS = 50_000_000;

// One photo at a time per server, with no image cache: little memory on a small VPS.
sharp.concurrency(1);
sharp.cache(false);

const FORMATS = {
  "image/jpeg": (image) => image.jpeg({ quality: 80, mozjpeg: true }),
  "image/png": (image) => image.png({ compressionLevel: 9 }),
  "image/webp": (image) => image.webp({ quality: 80 }),
};

/** The bytes to save for this file (photos shrunk; everything else unchanged). */
async function shrinkImage(bytes, mime) {
  const save = FORMATS[mime];
  if (!save) return bytes;
  try {
    const image = sharp(bytes, { limitInputPixels: MAX_PIXELS })
      .rotate()
      .resize({ width: MAX_SIDE, height: MAX_SIDE, fit: "inside", withoutEnlargement: true });
    // sharp leaves the hidden details out unless asked to keep them.
    return await save(image).toBuffer();
  } catch {
    throw new HttpError(415, "This photo can't be opened. Try taking it again.");
  }
}

module.exports = { shrinkImage, MAX_SIDE };
