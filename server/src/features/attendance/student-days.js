const { t } = require("../../i18n");
// A student's school day from the marks of its lessons: excused by the office
// → excused (with the office's note) absent from every marked lesson → absent
// (the only absent day) late to a lesson               → late, naming it
// otherwise                      → present Missed lessons on a day the student
// came are named in the note (the day still counts as attended).

/**
 * [marks]: [{ date, period, status, subjectName }]
 * [excuses]: [{ date, note }]
 * Returns [{ date, status, note, lessons }], newest day first.
 */
function studentDays(marks, excuses) {
  const byDate = new Map();
  for (const m of marks) {
    if (!byDate.has(m.date)) byDate.set(m.date, []);
    byDate.get(m.date).push(m);
  }
  const excused = new Map(excuses.map((e) => [e.date, e.note]));
  const dates = [...new Set([...byDate.keys(), ...excused.keys()])].sort().reverse();

  return dates.map((date) => {
    const lessons = (byDate.get(date) ?? [])
      .sort((a, b) => a.period - b.period)
      .map(({ period, status, subjectName }) => ({ period, status, subjectName }));
    return { date, ...dayStatus(lessons, excused.get(date)), lessons };
  });
}

function dayStatus(lessons, excuseNote) {
  if (excuseNote !== undefined) {
    return { status: "excused", note: excuseNote || t("Excused by the school") };
  }

  const absent = lessons.filter((l) => l.status === "absent");
  if (absent.length > 0 && absent.length === lessons.length) {
    return { status: "absent", note: null };
  }
  const late = lessons.filter((l) => l.status === "late");
  const notes = [
    absent.length > 0 &&
      t("Missed {0} of {1} lessons: {2}", [absent.length, lessons.length, names(absent)]),
    late.length > 0 && t("Late to {0}", [names(late)]),
  ].filter(Boolean);

  return {
    status: late.length > 0 ? "late" : "present",
    note: notes.length > 0 ? notes.join(" · ") : null,
  };
}

const names = (lessons) => lessons.map((l) => l.subjectName).join(t(", "));

module.exports = { studentDays };
