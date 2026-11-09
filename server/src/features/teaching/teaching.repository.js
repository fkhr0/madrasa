// SQL for a teacher's classes.
const { query } = require("../../db/database");
const { today } = require("../attendance/school-days");

/** Every class where the teacher teaches a subject, with the room it is usually in (from the timetable) and what waits for a grade: past exams without scores and handed-in homework. */
async function teacherClasses(teacherId) {
  const rows = await query(
    `SELECT DISTINCT ON (c.id)
            c.id, c.name,
            s.id AS "subjectId", s.name AS "subjectName", s.icon, s.color,
            (SELECT t.room FROM timetable_slots t
             WHERE t.class_id = c.id AND t.subject_id = s.id AND t.room <> ''
             GROUP BY t.room ORDER BY COUNT(*) DESC, t.room LIMIT 1) AS room,
            (SELECT COUNT(*)::int FROM users u
             WHERE u.institution_id = c.institution_id AND u.role = 'student'
               AND u.class_name = c.name AND u.is_active) AS "studentCount",
            (SELECT COUNT(*)::int FROM exams e
             WHERE e.class_id = c.id AND e.subject_id = s.id
               AND e.date <= $2 AND e.published_at IS NULL)
            + (SELECT COUNT(*)::int FROM submissions sb JOIN assignments a ON a.id = sb.assignment_id
               WHERE a.class_id = c.id AND a.subject_id = s.id
                 AND sb.submitted_at IS NOT NULL AND sb.grade IS NULL) AS "toGradeCount"
     FROM class_subjects cs
     JOIN classes c ON c.id = cs.class_id
     JOIN subjects s ON s.id = cs.subject_id
     WHERE cs.teacher_id = $1
     ORDER BY c.id, s.name`,
    [teacherId, today()],
  );

  return rows
    .map(({ subjectId, subjectName, icon, color, room, ...c }) => ({
      ...c,
      room: room ?? "",
      subject: { id: subjectId, name: subjectName, icon, color },
    }))
    .sort((a, b) => a.name.localeCompare(b.name));
}

module.exports = { teacherClasses };
