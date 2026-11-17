const { query } = require("../../db/database");
const { notify, audience } = require("../notifications/notify");

const ROLES = {
  school: ["student", "parent", "teacher", "admin"],
  parents: ["parent", "admin"],
  teachers: ["teacher", "admin"],
};

async function sendDueAnnouncements() {
  const due = await query(
    `UPDATE announcements SET notified = true
     WHERE NOT notified AND published_at <= now()
     RETURNING id, institution_id AS "institutionId", title, body, audience,
               class_id AS "classId", author_id AS "authorId", author_name AS "authorName"`,
  );
  for (const school of new Set(due.map((a) => a.institutionId))) {
    await require("../../common/cache").forgetSchool(school);
  }
  for (const a of due) {
    const people = await audience(a.institutionId, {
      roles: ROLES[a.audience] ?? [],
      classId: a.audience === "class" ? a.classId : null,
      exceptId: a.authorId,
    });
    await notify(a.institutionId, people, {
      type: "announcement",
      title: a.title,
      body: `${a.authorName} · ${a.body.slice(0, 120)}`,
      route: `/announcements/${a.id}`,
    });
  }
}

module.exports = { sendDueAnnouncements };
