const express = require("express");
const { HttpError } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const attendance = require("../attendance/attendance.repository");
const exams = require("../exams/exams.repository");
const repo = require("./teaching.repository");

const router = express.Router();
router.use(requireAuth, requireRole("teacher"));

router.get("/classes", async (req, res) => {
  res.json(await repo.teacherClasses(req.user.id));
});

router.get("/classes/:id/students", async (req, res) => {
  const teaching = (await repo.teacherClasses(req.user.id)).find(
    (c) => c.id === req.params.id,
  );
  if (!teaching) throw new HttpError(404, "You don't teach this class.");

  const rates = await attendance.subjectRates(teaching.id, teaching.subject.name);
  const averages = await exams.subjectAverages(teaching.id, teaching.subject.id);
  const students = await attendance.classStudents(teaching.id);
  res.json(
    students.map((s) => ({
      ...s,
      average: averages[s.id] ?? null,
      attendanceRate: rates[s.id] ?? null,
    })),
  );
});

module.exports = router;
