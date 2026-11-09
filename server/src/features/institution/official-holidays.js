// Iraq's official holidays, kept by the platform for every school.
const { query, queryOne } = require("../../db/database");

// study year name -> [key, name, type, start, end]
const OFFICIAL_HOLIDAYS = {
  "2026–2027": [
    ["national-day", "Iraqi National Day", "national", "2026-10-03", null],
    ["christmas", "Christmas", "religious", "2026-12-25", null],
    ["new-year", "New Year's Day", "national", "2027-01-01", null],
    ["army-day", "Army Day", "national", "2027-01-06", null],
    ["eid-al-fitr", "Eid al-Fitr", "religious", "2027-03-09", "2027-03-12"],
    ["nowruz", "Nowruz", "national", "2027-03-21", null],
    ["labour-day", "Labour Day", "national", "2027-05-01", null],
    ["eid-al-adha", "Eid al-Adha", "religious", "2027-05-16", "2027-05-19"],
    ["eid-al-ghadir", "Eid al-Ghadir", "religious", "2027-05-24", null],
    ["hijri-new-year", "Islamic New Year", "religious", "2027-06-06", null],
  ],
};

/**
 * Adds the official holidays a study year is missing (new year, or one
 * deleted before they were protected). Holidays already there keep the
 * dates the school set.
 */
async function addMissingOfficialHolidays(yearId) {
  const year = await queryOne(
    `SELECT name, start_date::text AS start, end_date::text AS "end"
     FROM academic_years WHERE id = $1`,
    [yearId],
  );
  let added = 0;
  for (const [key, name, type, start, end] of OFFICIAL_HOLIDAYS[year?.name] ?? []) {
    if (start < year.start || start > year.end) continue;
    const rows = await query(
      `INSERT INTO holidays (academic_year_id, official_key, name, type, start_date, end_date)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (academic_year_id, official_key) DO NOTHING
       RETURNING id`,
      [yearId, key, name, type, start, end],
    );
    added += rows.length;
  }
  return added;
}

/** Runs on start-up, so every school always has its official holidays. */
async function addMissingOfficialHolidaysEverywhere() {
  let added = 0;
  for (const { id } of await query("SELECT id FROM academic_years WHERE is_current")) {
    added += await addMissingOfficialHolidays(id);
  }
  return added;
}

module.exports = { addMissingOfficialHolidays, addMissingOfficialHolidaysEverywhere };
