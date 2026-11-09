// Writes one line to the activity log.
const { queryOne, query } = require("../../db/database");
const { render } = require("../../i18n");

const KINDS = [
  "attendance", "grades", "homework", "announcement", "people",
  "academics", "finance", "transport", "material", "security",
];

async function log(actor, { kind, action, summary, classId = null, studentIds = [], route = null }) {
  try {
    if (!KINDS.includes(kind)) throw new Error(`unknown kind ${kind}`);
    const who = await queryOne("SELECT name, role FROM users WHERE id = $1", [actor.id]);
    const name = who?.name ?? "Someone";
    const withName = (text) =>
      text.includes("{actor}") ? text.split("{actor}").join(name) : `${name} ${text}`;
    await query(
      `INSERT INTO activity_log (institution_id, actor_id, actor_name, actor_role, kind,
                                 action, summary, summary_ar, class_id, student_ids, route)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
      [
        actor.institutionId, actor.id, name, who?.role ?? actor.role ?? "",
        kind, action,
        withName(render(summary, "en")), withName(render(summary, "ar")),
        classId, [...new Set(studentIds)], route,
      ],
    );
  } catch (e) {
    console.warn(`Activity not logged (${action}): ${e.message}`);
  }
}

module.exports = { log, KINDS };
