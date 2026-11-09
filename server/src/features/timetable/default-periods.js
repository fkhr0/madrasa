// Every school starts with six 45-minute periods and a 20-minute break after
// the third. The administrator changes them in the app.
const { query } = require("../../db/database");

const DEFAULT_PERIODS = [
  ["08:00", "08:45"],
  ["08:50", "09:35"],
  ["09:40", "10:25"],
  ["10:45", "11:30"],
  ["11:35", "12:20"],
  ["12:25", "13:10"],
];

/** Gives the default bell times to every school that has none. */
async function addDefaultPeriodsEverywhere() {
  const schools = await query(
    `SELECT i.id FROM institutions i
     WHERE NOT EXISTS (SELECT 1 FROM periods p WHERE p.institution_id = i.id)`,
  );
  for (const { id } of schools) {
    for (const [i, [start, end]] of DEFAULT_PERIODS.entries()) {
      await query(
        `INSERT INTO periods (institution_id, number, start_time, end_time)
         VALUES ($1, $2, $3, $4)`,
        [id, i + 1, start, end],
      );
    }
  }
  return schools.length;
}

module.exports = { addDefaultPeriodsEverywhere };
