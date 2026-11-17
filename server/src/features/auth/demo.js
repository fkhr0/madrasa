const config = require("../../config");
const { query } = require("../../db/database");
const { DEMO_ACCOUNTS, DEMO_SCHOOLS, seedDemoSchool } = require("../../db/seed");
const { HttpError } = require("../../common/http");

const DEMO_IDS = new Set(Object.values(DEMO_ACCOUNTS));

const isDemoAccount = (userId) => config.demoMode && DEMO_IDS.has(userId);

function notOnDemoAccount(userId) {
  if (isDemoAccount(userId)) {
    throw new HttpError(403, "Not available in the demo school.");
  }
}

async function resetDemoSchool() {
  if (!config.demoMode) return null;
  await query("DELETE FROM users WHERE institution_id = ANY($1)", [DEMO_SCHOOLS]);
  await query("DELETE FROM academic_years WHERE institution_id = ANY($1)", [DEMO_SCHOOLS]);
  await query("DELETE FROM institutions WHERE id = ANY($1)", [DEMO_SCHOOLS]);
  const { addMissingOfficialHolidaysEverywhere } = require("../institution/official-holidays");
  const { addDefaultPeriodsEverywhere } = require("../timetable/default-periods");
  const added = await seedDemoSchool({
    beforeHistory: {
      defaults: async () => {
        await addMissingOfficialHolidaysEverywhere();
        await addDefaultPeriodsEverywhere();
      },
    },
  });
  for (const school of DEMO_SCHOOLS) {
    await require("../../common/cache").forgetSchool(school);
  }
  return added;
}

module.exports = { DEMO_ACCOUNTS, isDemoAccount, notOnDemoAccount, resetDemoSchool };
