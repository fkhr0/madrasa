// Draws assets/icon/*.png.
const sharp = require(require.resolve("sharp", { paths: [process.cwd()] }));
const out = process.argv[2];
const book = "M22.47,5.2C22,4.96,21.51,4.76,21,4.59v12.03C19.86,16.21,18.69,16,17.5,16c-1.9,0-3.78,0.54-5.5,1.58V5.48 C10.38,4.55,8.51,4,6.5,4C4.71,4,3.02,4.44,1.53,5.2C1.2,5.36,1,5.71,1,6.08v12.08c0,0.58,0.47,0.99,1,0.99 c0.16,0,0.32-0.04,0.48-0.12C3.69,18.4,5.05,18,6.5,18c2.07,0,3.98,0.82,5.5,2c1.52-1.18,3.43-2,5.5-2c1.45,0,2.81,0.4,4.02,1.04 c0.16,0.08,0.32,0.12,0.48,0.12c0.52,0,1-0.41,1-0.99V6.08C23,5.71,22.8,5.36,22.47,5.2z M10,16.62C8.86,16.21,7.69,16,6.5,16 c-1.19,0-2.36,0.21-3.5,0.62V6.71C4.11,6.24,5.28,6,6.5,6C7.7,6,8.89,6.25,10,6.72V16.62z M19,0.5l-5,5V15l5-4.5V0.5z";
const gradient = `<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4C5FD5"/><stop offset="1" stop-color="#7A5AD8"/></linearGradient></defs>`;
// The book at [scale] of the 1024 square, centred.
const bookAt = (scale) => {
  const size = 1024 * scale, k = size / 24, off = (1024 - size) / 2;
  return `<g transform="translate(${off} ${off}) scale(${k})"><path fill="#fff" d="${book}"/></g>`;
};
const svg = (body) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024">${body}</svg>`);
(async () => {
  // Old phones and the Play Store: the whole square (they round it themselves).
  await sharp(svg(`${gradient}<rect width="1024" height="1024" fill="url(#g)"/>${bookAt(0.58)}`)).png().toFile(`${out}/icon.png`);
  await sharp(`${out}/icon.png`).resize(512).png().toFile(`${out}/play-store-512.png`);
  // Android 8+: the background and the book apart (the phone picks the shape).
  await sharp(svg(`${gradient}<rect width="1024" height="1024" fill="url(#g)"/>`)).png().toFile(`${out}/background.png`);
  // flutter_launcher_icons insets it 16% per side: ends up ~42%, inside the
  // middle 66% that every icon shape shows.
  await sharp(svg(bookAt(0.62))).png().toFile(`${out}/foreground.png`);
  console.log("icons made");
})();
