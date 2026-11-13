// Telling people things: saves one notification per person.
// Every feature calls notify(); who to tell is worked out with the helpers.
const { query } = require("../../db/database");
const { render } = require("../../i18n");
const { chunks } = require("../../common/chunks");

const PEOPLE_PER_PUSH_JOB = 500;

/** Saves the notification for each of [userIds] (duplicates and empty IDs are skipped), in English and Arabic: the app shows the language it is set to now. */
async function notify(institutionId, userIds, { type, title, body = "", route = null }) {
  const ids = [...new Set(userIds.filter(Boolean))];
  if (ids.length === 0) return;
  try {
    const texts = {
      en: { title: render(title, "en"), body: render(body, "en") ?? "" },
      ar: { title: render(title, "ar"), body: render(body, "ar") ?? "" },
    };
    await query(
      `INSERT INTO notifications (institution_id, user_id, type, title, body, title_ar, body_ar, route)
       SELECT $1, id, $3, $4, $5, $6, $7, $8 FROM unnest($2::text[]) AS id`,
      [institutionId, ids, type, texts.en.title, texts.en.body, texts.ar.title, texts.ar.body, route],
    );
    // Phones get it too (each in its app's language), from background jobs so a
    // message to the whole school doesn't slow this request down.
    for (const part of chunks(ids, PEOPLE_PER_PUSH_JOB)) {
      require("../../jobs/queue")
        .enqueue("push.send", { userIds: part, texts, route })
        .catch(() => {});
    }
    // Open apps reload their notifications at once.
    require("../../realtime/hub").publish(ids, { type: "notification.new" });
  } catch (e) {
    console.warn(`Notification "${render(title, "en")}" not saved: ${e.message}`);
  }
}

// ---------- Who to tell ----------

/** The school's administrators (the office). */
async function admins(institutionId) {
  const rows = await query(
    "SELECT id FROM users WHERE institution_id = $1 AND role = 'admin' AND is_active",
    [institutionId],
  );
  return rows.map((r) => r.id);
}

/** Each student and their parents. */
async function withParents(studentIds) {
  if (studentIds.length === 0) return [];
  const rows = await query(
    "SELECT parent_id AS id FROM parent_children WHERE child_id = ANY($1)",
    [studentIds],
  );
  return [...studentIds, ...rows.map((r) => r.id)];
}

/** Everyone an announcement or event is for, without drivers (they only hear about their bus) and without [exceptId] (the person who wrote it). */
async function audience(institutionId, { roles, classId = null, exceptId = null }) {
  let rows;
  if (classId) {
    rows = await query(
      `SELECT u.id FROM users u JOIN classes c ON c.name = u.class_name
         WHERE c.id = $1 AND u.role = 'student' AND u.is_active
       UNION SELECT pc.parent_id FROM parent_children pc
         JOIN users u ON u.id = pc.child_id JOIN classes c ON c.name = u.class_name
         WHERE c.id = $1
       UNION SELECT teacher_id FROM class_subjects WHERE class_id = $1 AND teacher_id IS NOT NULL
       UNION SELECT homeroom_teacher_id FROM classes WHERE id = $1 AND homeroom_teacher_id IS NOT NULL`,
      [classId],
    );
  } else {
    rows = await query(
      "SELECT id FROM users WHERE institution_id = $1 AND role = ANY($2) AND is_active",
      [institutionId, roles],
    );
  }
  return rows.map((r) => r.id).filter((id) => id !== exceptId);
}

module.exports = { notify, admins, withParents, audience };
