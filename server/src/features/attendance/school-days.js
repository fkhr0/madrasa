// Which dates are school days: inside the study year, on a study weekday,
// and not a holiday. Dates are "YYYY-MM-DD" in the school's local time.
const config = require("../../config");
const institution = require("../institution/institution.repository");

/**
 * Today as "YYYY-MM-DD" on the school's clock (config.timeZone), so a
 * server abroad still knows the Iraqi date.
 */
function today(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: config.timeZone }).format(now);
}

/** The time on the school's clock, "HH:MM". */
function timeNow(now = new Date()) {
  return new Intl.DateTimeFormat("en-GB", {
    timeZone: config.timeZone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).format(now);
}

function isoDay(d) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

/** 1 = Monday … 7 = Sunday, like Dart's DateTime.weekday. */
function weekdayOf(date) {
  const day = new Date(`${date}T12:00:00`).getDay(); // 0 = Sunday
  return day === 0 ? 7 : day;
}

/** "2026-11-08" minus [days] days. */
function addDays(date, days) {
  const d = new Date(`${date}T12:00:00`);
  d.setDate(d.getDate() + days);
  return isoDay(d);
}

/**
 * The school's calendar: { year, isSchoolDay(date), dayOffReason(date) }.
 * null when the school has no study year.
 */
async function schoolCalendar(institutionId) {
  const year = await institution.findCurrentYear(institutionId);
  if (!year) return null;
  const holidays = await institution.findHolidays(year.id);

  /** Why there is no school on [date] ("Weekend", a holiday's name…), or null. */
  const dayOffReason = (date) => {
    if (date < year.start || date > year.end) return "Outside the study year";
    if (!year.working_days.includes(weekdayOf(date))) return "Weekend";
    const holiday = holidays.find((h) => date >= h.start && date <= (h.end ?? h.start));
    return holiday ? holiday.name : null;
  };

  return {
    year,
    dayOffReason,
    isSchoolDay: (date) => dayOffReason(date) === null,
  };
}

module.exports = { today, timeNow, isoDay, weekdayOf, addDays, schoolCalendar };
