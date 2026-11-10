// Which files can be uploaded, and how each is served back.

const ascii = (bytes, from, text) =>
  bytes.subarray(from, from + text.length).toString("latin1") === text;
const startsWith = (bytes, ...values) => values.every((v, i) => bytes[i] === v);

const is = {
  pdf: (b) => ascii(b, 0, "%PDF"),
  png: (b) => startsWith(b, 0x89, 0x50, 0x4e, 0x47),
  jpeg: (b) => startsWith(b, 0xff, 0xd8, 0xff),
  gif: (b) => ascii(b, 0, "GIF8"),
  webp: (b) => ascii(b, 0, "RIFF") && ascii(b, 8, "WEBP"),
  // HEIC photos (iPhone), MP4 videos and M4A audio share the "ftyp" box.
  ftyp: (b) => ascii(b, 4, "ftyp"),
  // Word, Excel and PowerPoint: new ones are zip files, old ones OLE files.
  zip: (b) => ascii(b, 0, "PK\u0003\u0004"),
  ole: (b) => startsWith(b, 0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1),
  mp3: (b) => ascii(b, 0, "ID3") || (b[0] === 0xff && (b[1] & 0xe0) === 0xe0),
  // Plain text: no zero bytes near the start.
  text: (b) => !b.subarray(0, 4096).includes(0),
};

/** extension -> how to check it, what to call it, whether to show it in the browser. */
const TYPES = {
  pdf: { check: is.pdf, mime: "application/pdf", inline: true },
  jpg: { check: is.jpeg, mime: "image/jpeg", inline: true },
  jpeg: { check: is.jpeg, mime: "image/jpeg", inline: true },
  png: { check: is.png, mime: "image/png", inline: true },
  gif: { check: is.gif, mime: "image/gif", inline: true },
  webp: { check: is.webp, mime: "image/webp", inline: true },
  heic: { check: is.ftyp, mime: "image/heic", inline: false },
  mp4: { check: is.ftyp, mime: "video/mp4", inline: true },
  m4a: { check: is.ftyp, mime: "audio/mp4", inline: true },
  mp3: { check: is.mp3, mime: "audio/mpeg", inline: true },
  docx: { check: is.zip, mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
  xlsx: { check: is.zip, mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" },
  pptx: { check: is.zip, mime: "application/vnd.openxmlformats-officedocument.presentationml.presentation" },
  doc: { check: is.ole, mime: "application/msword" },
  xls: { check: is.ole, mime: "application/vnd.ms-excel" },
  ppt: { check: is.ole, mime: "application/vnd.ms-powerpoint" },
  txt: { check: is.text, mime: "text/plain; charset=utf-8" },
  csv: { check: is.text, mime: "text/csv; charset=utf-8" },
};

const extensionOf = (name) => (name.includes(".") ? name.split(".").pop().toLowerCase() : "");

/** The type for a file name, or null when that kind of file isn't allowed. */
function typeOf(name) {
  return TYPES[extensionOf(name)] ?? null;
}

/** true when the bytes really are what the name says. */
function matches(type, bytes) {
  if (!Buffer.isBuffer(bytes)) return false;
  // Text can be a single letter; every other kind has a longer signature.
  return (type.check === is.text || bytes.length >= 4) && type.check(bytes);
}

/** Shown in the "not allowed" message. */
const ALLOWED = Object.keys(TYPES).join(", ");

module.exports = { typeOf, matches, ALLOWED };
