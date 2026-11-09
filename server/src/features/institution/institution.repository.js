// SQL for the school and its study year. Dates are returned as "YYYY-MM-DD"
// text (::text), so no time zone can move a holiday to the day before.
const { query, queryOne } = require("../../db/database");

const INSTITUTION = "id, name, city, address, phone, latitude, longitude";

function findInstitution(id) {
  return queryOne(`SELECT ${INSTITUTION} FROM institutions WHERE id = $1`, [id]);
}

function updateInstitution(id, i) {
  return queryOne(
    `UPDATE institutions
     SET name = $2, city = $3, address = $4, phone = $5, latitude = $6, longitude = $7
     WHERE id = $1
     RETURNING ${INSTITUTION}`,
    [id, i.name, i.city, i.address, i.phone, i.latitude ?? null, i.longitude ?? null],
  );
}

function updateWorkingDays(yearId, workingDays) {
  return query("UPDATE academic_years SET working_days = $2 WHERE id = $1", [
    yearId,
    workingDays,
  ]);
}

function findCurrentYear(institutionId) {
  return queryOne(
    `SELECT id, name, start_date::text AS start, end_date::text AS "end",
            working_days
     FROM academic_years
     WHERE institution_id = $1 AND is_current
     LIMIT 1`,
    [institutionId],
  );
}

function findTerms(yearId) {
  return query(
    `SELECT name, start_date::text AS start, end_date::text AS "end"
     FROM terms WHERE academic_year_id = $1 ORDER BY start_date`,
    [yearId],
  );
}

const HOLIDAY = `id, name, type, start_date::text AS start, end_date::text AS "end",
  official_key IS NOT NULL AS "isOfficial"`;

function findHoliday(yearId, holidayId) {
  return queryOne(
    `SELECT ${HOLIDAY} FROM holidays WHERE id = $1 AND academic_year_id = $2`,
    [holidayId, yearId],
  );
}

function findHolidays(yearId) {
  return query(
    `SELECT ${HOLIDAY} FROM holidays WHERE academic_year_id = $1 ORDER BY start_date`,
    [yearId],
  );
}

function insertHoliday(yearId, { name, type, start, end }) {
  return queryOne(
    `INSERT INTO holidays (academic_year_id, name, type, start_date, end_date)
     VALUES ($1, $2, $3, $4, $5)
     RETURNING ${HOLIDAY}`,
    [yearId, name, type, start, end ?? null],
  );
}

function updateHoliday(yearId, holidayId, { name, type, start, end }) {
  return queryOne(
    `UPDATE holidays SET name = $3, type = $4, start_date = $5, end_date = $6
     WHERE id = $1 AND academic_year_id = $2
     RETURNING ${HOLIDAY}`,
    [holidayId, yearId, name, type, start, end ?? null],
  );
}

/** Deletes only inside the given year, so one school can't touch another's. */
async function deleteHoliday(yearId, holidayId) {
  const rows = await query(
    "DELETE FROM holidays WHERE id = $1 AND academic_year_id = $2 RETURNING id",
    [holidayId, yearId],
  );
  return rows.length > 0;
}

module.exports = {
  findInstitution,
  updateInstitution,
  findCurrentYear,
  findTerms,
  updateWorkingDays,
  findHoliday,
  findHolidays,
  insertHoliday,
  updateHoliday,
  deleteHoliday,
};
