// Reminders the school sends by itself (all times on the school's clock): 7:00
// exams today               → the class's students and parents 18:00  exams
// tomorrow            → the class's students and parents homework due tomorrow
// → students who haven't handed it in every minute   personal reminders the
// user set in Tasks every 5 min    a lesson started 10 min ago without
// attendance → its teacher Each reminder is sent once (sent_reminders), even if
// a job runs again.
const { query, queryOne } = require("../db/database");
const { notify, withParents } = require("../features/notifications/notify");
const attendance = require("../features/attendance/attendance.repository");
const { today, timeNow, addDays, weekdayOf, schoolCalendar } = require("../features/attendance/school-days");
const config = require("../config");
const { msg } = require("../i18n");

const TYPE_NAMES = {
  quiz: "quiz",
  monthly: "monthly exam",
  midYear: "mid-year exam",
  final: "final exam",
};

/** True the first time [key] is claimed; false if it was sent before. */
async function once(key) {
  return Boolean(
    await queryOne(
      "INSERT INTO sent_reminders (key) VALUES ($1) ON CONFLICT DO NOTHING RETURNING key",
      [key],
    ),
  );
}

async function institutions() {
  return (await query("SELECT id FROM institutions")).map((r) => r.id);
}

/** Exams on [date] at schools where it is a school day. */
async function examsOn(date) {
  const exams = [];
  for (const id of await institutions()) {
    const calendar = await schoolCalendar(id);
    if (!calendar?.isSchoolDay(date)) continue;
    exams.push(
      ...(await query(
        `SELECT e.id, e.institution_id AS "institutionId", e.class_id AS "classId",
                e.type, e.title, to_char(e.start_time, 'HH24:MI') AS "startTime", e.room,
                s.name AS "subjectName"
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         WHERE e.institution_id = $1 AND e.date = $2`,
        [id, date],
      )),
    );
  }
  return exams;
}

async function remindExams(date, when) {
  let sent = 0;
  for (const exam of await examsOn(date)) {
    if (!(await once(`exam-${when}:${exam.id}`))) continue;
    const students = await attendance.classStudents(exam.classId);
    await notify(exam.institutionId, await withParents(students.map((s) => s.id)), {
      type: "schedule",
      title: when === "today"
        ? msg("{0} {1} today at {2}", exam.subjectName, msg(TYPE_NAMES[exam.type]), exam.startTime)
        : msg("{0} {1} tomorrow at {2}", exam.subjectName, msg(TYPE_NAMES[exam.type]), exam.startTime),
      body: [exam.title, exam.room].filter(Boolean).join(" · "),
      route: "/exams",
    });
    sent++;
  }
  return sent;
}

// Each job takes an optional { date, time } (tests); the scheduler uses now.

/** 7:00: exams today. */
function examsToday({ date = today() } = {}) {
  return remindExams(date, "today");
}

/** 18:00: exams and homework due tomorrow. */
async function eveningReminders({ date = today() } = {}) {
  const tomorrow = addDays(date, 1);
  const exams = await remindExams(tomorrow, "tomorrow");

  const due = await query(
    `SELECT a.id, a.institution_id AS "institutionId", a.class_id AS "classId",
            a.title, s.name AS "subjectName"
     FROM assignments a JOIN subjects s ON s.id = a.subject_id
     WHERE (a.due_at AT TIME ZONE $2)::date = $1`,
    [tomorrow, config.timeZone],
  );
  let homework = 0;
  for (const a of due) {
    if (!(await once(`homework-tomorrow:${a.id}`))) continue;
    const students = await attendance.classStudents(a.classId);
    const handedIn = new Set(
      (
        await query(
          "SELECT student_id FROM submissions WHERE assignment_id = $1 AND submitted_at IS NOT NULL",
          [a.id],
        )
      ).map((r) => r.student_id),
    );
    const notYet = students.map((s) => s.id).filter((id) => !handedIn.has(id));
    await notify(a.institutionId, notYet, {
      type: "assignment",
      title: msg("Due tomorrow: {0}", a.title),
      body: msg("{0} · hand it in before the end of the day", a.subjectName),
      route: `/assignments/${a.id}`,
    });
    homework++;
  }
  return { exams, homework };
}

const REPEAT = { daily: "1 day", weekly: "7 days", monthly: "1 month" };

/** Every minute - personal reminders that are due. */
async function taskReminders() {
  const due = await query(
    `SELECT t.user_id AS "userId", t.id, t.title, t.due_at AS "dueAt", t.repeat, t.route,
            u.institution_id AS "institutionId"
     FROM tasks t JOIN users u ON u.id = t.user_id
     WHERE t.is_reminder AND NOT t.is_done
       AND t.due_at <= now() AND t.due_at > now() - interval '1 day'`,
  );
  for (const t of due) {
    if (!(await once(`task:${t.userId}:${t.id}:${new Date(t.dueAt).getTime()}`))) continue;
    await notify(t.institutionId, [t.userId], {
      type: "reminder",
      title: t.title,
      body: msg("Your reminder"),
      route: t.route || "/tasks",
    });
    if (REPEAT[t.repeat]) {
      await query(
        `UPDATE tasks SET due_at = due_at + $3::interval WHERE user_id = $1 AND id = $2`,
        [t.userId, t.id, REPEAT[t.repeat]],
      );
    }
  }
  return due.length;
}

/** How long after a lesson starts its teacher is reminded to take attendance. */
const ATTENDANCE_GRACE_MIN = 10;

/** Every 5 minutes: lessons under way without attendance. */
async function attendanceReminders({ date = today(), time = timeNow() } = {}) {
  const now = time;
  let sent = 0;

  for (const id of await institutions()) {
    const calendar = await schoolCalendar(id);
    if (!calendar?.isSchoolDay(date)) continue;
    const lessons = await query(
      `SELECT t.class_id AS "classId", c.name AS "className", t.period,
              s.name AS "subjectName", cs.teacher_id AS "teacherId"
       FROM timetable_slots t
       JOIN classes c ON c.id = t.class_id
       JOIN subjects s ON s.id = t.subject_id
       JOIN class_subjects cs ON cs.class_id = t.class_id AND cs.subject_id = t.subject_id
       JOIN periods p ON p.institution_id = c.institution_id AND p.number = t.period
       WHERE c.institution_id = $1 AND t.weekday = $2 AND cs.teacher_id IS NOT NULL
         AND p.start_time + make_interval(mins => $4) <= $3::time
         AND p.end_time >= $3::time
         AND NOT EXISTS (SELECT 1 FROM attendance_marks m
                         WHERE m.class_id = t.class_id AND m.date = $5 AND m.period = t.period)`,
      [id, weekdayOf(date), now, ATTENDANCE_GRACE_MIN, date],
    );
    for (const l of lessons) {
      if (!(await once(`attendance:${l.classId}:${date}:${l.period}`))) continue;
      await notify(id, [l.teacherId], {
        type: "attendance",
        title: msg("Take attendance: {0}", l.className),
        body: msg("Period {0} · {1}", l.period, l.subjectName),
        route: `/classes/${l.classId}/attendance`,
      });
      sent++;
    }
  }
  return sent;
}

module.exports = {
  once,
  examsToday,
  eveningReminders,
  taskReminders,
  attendanceReminders,
};
