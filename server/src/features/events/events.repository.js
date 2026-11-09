// SQL for school events. Always limited to one institution.
const { query, queryOne } = require("../../db/database");

const COLUMNS = `id, title, type, audience, event_date::text AS date,
  start_time AS time, end_date::text AS "endDate", place, details`;

function list(institutionId, audiences) {
  return query(
    `SELECT ${COLUMNS} FROM school_events
     WHERE institution_id = $1 AND audience = ANY($2)
     ORDER BY event_date, start_time NULLS FIRST`,
    [institutionId, audiences],
  );
}

function insert(institutionId, userId, e) {
  return queryOne(
    `INSERT INTO school_events (institution_id, created_by, title, type, audience,
                                event_date, start_time, end_date, place, details)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING ${COLUMNS}`,
    [
      institutionId,
      userId,
      e.title,
      e.type,
      e.audience,
      e.date,
      e.time ?? null,
      e.endDate ?? null,
      e.place,
      e.details,
    ],
  );
}

function update(institutionId, id, e) {
  return queryOne(
    `UPDATE school_events
     SET title = $3, type = $4, audience = $5, event_date = $6, start_time = $7,
         end_date = $8, place = $9, details = $10
     WHERE institution_id = $1 AND id = $2
     RETURNING ${COLUMNS}`,
    [
      institutionId,
      id,
      e.title,
      e.type,
      e.audience,
      e.date,
      e.time ?? null,
      e.endDate ?? null,
      e.place,
      e.details,
    ],
  );
}

async function remove(institutionId, id) {
  const rows = await query(
    "DELETE FROM school_events WHERE institution_id = $1 AND id = $2 RETURNING id",
    [institutionId, id],
  );
  return rows.length > 0;
}

module.exports = { list, insert, update, remove };
