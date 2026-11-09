// "Only the subject's teacher or the school office": who may manage a
// subject's exams and homework in a class.
const { HttpError } = require("../../common/http");

/** (subjectId) → may [user] manage that subject in [schoolClass]? */
function taughtBy(user, schoolClass) {
  if (user.role === "admin") return () => true;
  const mine = new Set(
    schoolClass.subjects.filter((s) => s.teacherId === user.id).map((s) => s.subjectId),
  );
  return (subjectId) => mine.has(subjectId);
}

function checkTeaches(user, schoolClass, subjectId) {
  if (!taughtBy(user, schoolClass)(subjectId)) {
    throw new HttpError(403, "Only the subject's teacher or the school office can do this.");
  }
}

module.exports = { taughtBy, checkTeaches };
