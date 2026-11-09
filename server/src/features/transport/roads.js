// Keeps each bus line's road up to date: after its stops are saved, when
// the school moves, and on start-up for lines that never had one.
const repo = require("./transport.repository");
const { roadThrough } = require("./maps");

/**
 * Works out both trips of one line on the roads and saves them. Never
 * throws: if the routing service is down, the line keeps straight lines.
 */
async function updateRoads(institutionId, routeId) {
  const route = await repo.findRoute(institutionId, routeId);
  if (!route) return;
  try {
    const toSchool = await roadThrough(route.stops);
    // Streets can be one-way: the afternoon trip is worked out on its own.
    const toHome = toSchool && (await roadThrough([...route.stops].reverse()));
    await repo.saveRoads(route.id, toSchool, toHome);
  } catch (e) {
    console.warn(`Road for ${route.name} not worked out: ${e.message}`);
  }
}

/** Every line of a school (after the school moved on the map). */
async function updateSchoolRoads(institutionId) {
  for (const route of await repo.findRoutes(institutionId)) {
    await updateRoads(institutionId, route.id);
  }
}

/** Start-up: lines that never had a road, one after another. */
async function fillMissingRoads() {
  for (const { id, institutionId } of await repo.findRoutesWithoutRoads()) {
    await updateRoads(institutionId, id);
  }
}

module.exports = { updateRoads, updateSchoolRoads, fillMissingRoads };
