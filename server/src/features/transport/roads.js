const repo = require("./transport.repository");
const { roadThrough } = require("./maps");

async function updateRoads(institutionId, routeId) {
  const route = await repo.findRoute(institutionId, routeId);
  if (!route) return;
  try {
    const toSchool = await roadThrough(route.stops);
    const toHome = toSchool && (await roadThrough([...route.stops].reverse()));
    await repo.saveRoads(route.id, toSchool, toHome);
  } catch (e) {
    console.warn(`Road for ${route.name} not worked out: ${e.message}`);
  }
}

async function updateSchoolRoads(institutionId) {
  for (const route of await repo.findRoutes(institutionId)) {
    await updateRoads(institutionId, route.id);
  }
}

async function fillMissingRoads() {
  for (const { id, institutionId } of await repo.findRoutesWithoutRoads()) {
    await updateRoads(institutionId, id);
  }
}

module.exports = { updateRoads, updateSchoolRoads, fillMissingRoads };
