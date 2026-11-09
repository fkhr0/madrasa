// The signed-in user's school and its study year.
// Everyone reads; only administrators change.
const express = require("express");
const { HttpError, validate, isoDate, z } = require("../../common/http");
const { requireAuth, requireRole } = require("../../common/auth-middleware");
const repo = require("./institution.repository");
const { t } = require("../../i18n");
const { cachedForSchool } = require("../../common/cache");

const router = express.Router();
// Only these paths: the router is mounted at "/", next to the app's files.
router.use(["/institution", "/academic-year"], requireAuth);

// GET /institution -> { id, name, city, address, phone, latitude, longitude }
router.get("/institution", async (req, res) => {
  const id = req.user.institutionId;
  res.json(await cachedForSchool(id, "institution", () => repo.findInstitution(id)));
});

// PATCH /institution { name, city, address, phone, latitude, longitude }
//   -> institution  (admin)
router.patch("/institution", requireRole("admin"), async (req, res) => {
  const body = validate(
    z
      .object({
        name: z.string().trim().min(3).max(120),
        city: z.string().trim().max(60).default(""),
        address: z.string().trim().max(200).default(""),
        phone: z.string().trim().max(30).default(""),
        // The school's gate on the map; both or neither.
        latitude: z.number().min(-90).max(90).nullish(),
        longitude: z.number().min(-180).max(180).nullish(),
      })
      .refine((i) => (i.latitude == null) === (i.longitude == null), {
        message: "send both latitude and longitude",
      }),
    req.body,
  );
  const before = await repo.findInstitution(req.user.institutionId);
  const updated = await repo.updateInstitution(req.user.institutionId, body);
  // Every bus line ends at the school: redraw them when it moves.
  if (before.latitude !== updated.latitude || before.longitude !== updated.longitude) {
    require("../transport/roads").updateSchoolRoads(req.user.institutionId);
  }
  res.json(updated);
});

// GET /academic-year -> { id, name, start, end, workingDays, terms, holidays }
router.get("/academic-year", async (req, res) => {
  const id = req.user.institutionId;
  res.json(await cachedForSchool(id, `year:${req.language}`, () => yearOf(req)));
});

async function yearOf(req) {
  const year = await currentYear(req);

  return {
    id: year.id,
    name: year.name,
    start: year.start,
    end: year.end,
    workingDays: year.working_days,
    terms: await repo.findTerms(year.id),
    // Official holidays (the platform's list) in the caller's language.
    holidays: (await repo.findHolidays(year.id)).map((h) =>
      h.isOfficial ? { ...h, name: t(h.name) } : h,
    ),
  };
}

// PATCH /academic-year { workingDays } -> 204  (admin)
// Days use Dart's numbers: 1 = Monday ... 7 = Sunday.
router.patch("/academic-year", requireRole("admin"), async (req, res) => {
  const year = await currentYear(req);
  const { workingDays } = validate(
    z.object({
      workingDays: z
        .array(z.number().int().min(1).max(7))
        .min(1, "choose at least one study day")
        .transform((days) => [...new Set(days)].sort()),
    }),
    req.body,
  );
  await repo.updateWorkingDays(year.id, workingDays);
  res.status(204).end();
});

/** A holiday's fields, checked against the study year. */
const holidayFields = (year) =>
  z
    .object({
      name: z.string().trim().min(2).max(80),
      type: z.enum(["schoolBreak", "national", "religious"]),
      start: isoDate,
      end: isoDate.nullish(),
    })
    .refine((h) => !h.end || h.end >= h.start, {
      message: "end must be on or after start",
    })
    .refine((h) => h.start >= year.start && h.start <= year.end, {
      message: "the holiday must be inside the study year",
    });

// POST /academic-year/holidays { name, type, start, end? } -> holiday  (admin)
router.post(
  "/academic-year/holidays",
  requireRole("admin"),
  async (req, res) => {
    const year = await currentYear(req);
    const body = validate(holidayFields(year), req.body);
    res.status(201).json(await repo.insertHoliday(year.id, body));
  },
);

// PATCH /academic-year/holidays/:id { name, type, start, end? } -> holiday  (admin)
router.patch(
  "/academic-year/holidays/:id",
  requireRole("admin"),
  async (req, res) => {
    const year = await currentYear(req);
    const body = validate(holidayFields(year), req.body);
    const old = await repo.findHoliday(year.id, req.params.id);
    if (!old) throw new HttpError(404, "Holiday not found.");

    // Official holidays keep their name and type; only the dates move.
    const holiday = await repo.updateHoliday(
      year.id,
      old.id,
      old.isOfficial ? { ...body, name: old.name, type: old.type } : body,
    );
    res.json(holiday);
  },
);

// DELETE /academic-year/holidays/:id -> 204  (admin)
router.delete(
  "/academic-year/holidays/:id",
  requireRole("admin"),
  async (req, res) => {
    const year = await currentYear(req);
    const old = await repo.findHoliday(year.id, req.params.id);
    if (!old) throw new HttpError(404, "Holiday not found.");
    if (old.isOfficial) {
      throw new HttpError(409, "{0} is an official holiday and can't be deleted. You can change its dates.", [old.name],
      );
    }
    await repo.deleteHoliday(year.id, old.id);
    res.status(204).end();
  },
);

async function currentYear(req) {
  const year = await repo.findCurrentYear(req.user.institutionId);
  if (!year) throw new HttpError(404, "The school has no study year yet.");
  return year;
}

module.exports = router;
