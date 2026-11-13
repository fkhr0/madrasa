// "Try the demo": anyone opens the demo school as a student, parent, teacher,
// the office or the driver, without a password (DEMO_MODE=true).
const config = require("../../config");
const { query } = require("../../db/database");
const { DEMO_ACCOUNTS, DEMO_SCHOOLS, seedDemoSchool } = require("../../db/seed");
const { HttpError } = require("../../common/http");

const DEMO_IDS = new Set(Object.values(DEMO_ACCOUNTS));

/** One of the accounts "Try the demo" opens (only while the demo is on). */
const isDemoAccount = (userId) => config.demoMode && DEMO_IDS.has(userId);

/** Refuses actions that would spoil the demo for others. */
function notOnDemoAccount(userId) {
  if (isDemoAccount(userId)) {
    throw new HttpError(403, "Not available in the demo school.");
  }
}

/**
 * Every night: the demo school is deleted and made again with fresh dates
 * (today's lessons, this week's homework…). Real schools aren't touched.
 */
async function resetDemoSchool() {
  if (!config.demoMode) return null;
  // People and study years first (they aren't deleted with a school by design,
  // so a real school can't vanish with one mistake), then the schools and
  // everything else that belongs to them.
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
