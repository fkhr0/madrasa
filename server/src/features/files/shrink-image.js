const sharp = require("sharp");
const { HttpError } = require("../../common/http");

const MAX_SIDE = 1600;
const MAX_PIXELS = 50_000_000;

sharp.concurrency(1);
sharp.cache(false);

const FORMATS = {
  "image/jpeg": (image) => image.jpeg({ quality: 80, mozjpeg: true }),
  "image/png": (image) => image.png({ compressionLevel: 9 }),
  "image/webp": (image) => image.webp({ quality: 80 }),
};

async function shrinkImage(bytes, mime) {
  const save = FORMATS[mime];
  if (!save) return bytes;
  try {
    const image = sharp(bytes, { limitInputPixels: MAX_PIXELS })
      .rotate()
      .resize({ width: MAX_SIDE, height: MAX_SIDE, fit: "inside", withoutEnlargement: true });
    return await save(image).toBuffer();
  } catch {
    throw new HttpError(415, "This photo can't be opened. Try taking it again.");
  }
}

module.exports = { shrinkImage, MAX_SIDE };
