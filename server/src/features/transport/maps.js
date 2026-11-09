// Roads and places from OpenStreetMap's free services.
const OSRM_URL = process.env.OSRM_URL || "https://router.project-osrm.org";
const NOMINATIM_URL = process.env.NOMINATIM_URL || "https://nominatim.openstreetmap.org";
// The services ask every app to say who it is.
const USER_AGENT = "AlNoorSchoolApp/1.0 (school bus routes)";

// "off" (the tests): no network, lines stay straight and search is empty.
const OFF = OSRM_URL === "off";

let queue = Promise.resolve();

/** Runs [request] at least a second after the previous one. */
function oneAtATime(request) {
  const run = queue.then(request);
  queue = run.catch(() => {}).then(() => new Promise((r) => setTimeout(r, 1100)));
  return run;
}

async function getJson(url) {
  const res = await fetch(url, {
    headers: { "User-Agent": USER_AGENT, "Accept-Language": "en,ar" },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) throw new Error(`${new URL(url).host} answered ${res.status}`);
  return res.json();
}

const round = (n) => Math.round(n * 1e5) / 1e5;

/**
 * The road through [stops] ([{ latitude, longitude }], in driving order),
 * cut into one leg per stop-to-stop drive. Null when it can't be worked out.
 */
async function roadThrough(stops) {
  if (OFF || stops.length < 2) return null;
  const coordinates = stops.map((s) => `${s.longitude},${s.latitude}`).join(";");
  const url = `${OSRM_URL}/route/v1/driving/${coordinates}?overview=full&geometries=geojson`;

  const body = await oneAtATime(() => getJson(url));
  const route = body.routes?.[0];
  if (body.code !== "Ok" || !route) return null;

  // GeoJSON is [lng, lat]; the app uses [lat, lng].
  const points = route.geometry.coordinates.map(([lng, lat]) => [round(lat), round(lng)]);

  // Cut the line where it passes each stop (the closest point after the last cut).
  const cuts = [0];
  for (const w of body.waypoints.slice(1, -1)) {
    const [lng, lat] = w.location;
    let best = cuts.at(-1);
    let bestDistance = Infinity;
    for (let i = cuts.at(-1); i < points.length; i++) {
      const d = (points[i][0] - lat) ** 2 + (points[i][1] - lng) ** 2;
      if (d < bestDistance) [best, bestDistance] = [i, d];
    }
    cuts.push(best);
  }
  cuts.push(points.length - 1);

  return {
    legs: cuts.slice(1).map((end, i) => points.slice(cuts[i], end + 1)),
    metres: Math.round(route.distance),
    seconds: Math.round(route.duration),
    legSeconds: route.legs.map((l) => Math.round(l.duration)),
  };
}

/** Places matching [text] in Iraq, nearest to [near] first when given. */
async function searchPlaces(text, near) {
  if (OFF) return [];
  const params = new URLSearchParams({
    q: text,
    format: "jsonv2",
    countrycodes: "iq",
    limit: "8",
  });
  if (near) {
    // Prefer the school's area (about 40 km around it) without excluding others.
    const d = 0.35;
    params.set("viewbox", [near.longitude - d, near.latitude + d, near.longitude + d, near.latitude - d].join(","));
  }
  const results = await oneAtATime(() => getJson(`${NOMINATIM_URL}/search?${params}`));

  return results.map((r) => ({
    name: r.name || r.display_name.split(",")[0],
    address: r.display_name,
    latitude: Number(r.lat),
    longitude: Number(r.lon),
  }));
}

// Iraq's borders, roughly: places outside are refused (a typo, or the wrong link).
const IRAQ = { south: 29.0, north: 37.5, west: 38.7, east: 48.9 };

const inIraq = (p) =>
  p.latitude >= IRAQ.south && p.latitude <= IRAQ.north &&
  p.longitude >= IRAQ.west && p.longitude <= IRAQ.east;

/** Finds "lat,lng" in a map link or plain text, or null. */
function coordinatesIn(text) {
  const decoded = decodeURIComponent(text).replace(/\+/g, " ");
  const patterns = [
    /@(-?\d+\.\d+),\s*(-?\d+\.\d+)/, // google.com/maps/place/…/@33.3,44.3,17z
    /!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)/, // …!3d33.3!4d44.3 (the pin itself)
    /[?&](?:q|ll|query|destination|center)=(?:loc:)?(-?\d+\.\d+),\s*(-?\d+\.\d+)/,
    /geo:(-?\d+\.\d+),(-?\d+\.\d+)/,
    /^\s*(-?\d{1,2}\.\d+)\s*[, ]\s*(-?\d{1,3}\.\d+)\s*$/, // "33.3123, 44.3612"
  ];
  // Prefer the pin (!3d!4d) over the camera (@) when both are there.
  for (const pattern of [patterns[1], patterns[0], ...patterns.slice(2)]) {
    const m = decoded.match(pattern);
    if (m) return { latitude: Number(m[1]), longitude: Number(m[2]) };
  }
  return null;
}

// Short links that only say where they go after a redirect.
const SHORT_LINK_HOSTS = ["maps.app.goo.gl", "goo.gl", "g.co"];

/**
 * Reads a location from what a family sent: a WhatsApp / Google Maps link
 * (short ones are followed), or "33.31, 44.36". Null if none is found.
 * Only Google's short-link hosts are ever fetched.
 */
async function readLocation(text) {
  const direct = coordinatesIn(text);
  if (direct) return inIraq(direct) ? direct : null;
  if (OFF) return null;

  const link = text.match(/https?:\/\/\S+/)?.[0];
  if (!link) return null;
  let url = new URL(link);
  for (let hop = 0; hop < 5 && SHORT_LINK_HOSTS.includes(url.hostname); hop++) {
    const res = await fetch(url, {
      redirect: "manual",
      headers: { "User-Agent": USER_AGENT },
      signal: AbortSignal.timeout(10_000),
    });
    const next = res.headers.get("location");
    if (!next) break;
    url = new URL(next, url);
    const found = coordinatesIn(url.href);
    if (found) return inIraq(found) ? found : null;
  }
  return null;
}

module.exports = { roadThrough, searchPlaces, readLocation, coordinatesIn, inIraq };
