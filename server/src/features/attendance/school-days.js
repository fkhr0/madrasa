const config = require("../../config");
const institution = require("../institution/institution.repository");

function today(now = new Date()) {
  return new Intl.DateTimeFormat("en-CA", { timeZone: config.timeZone }).format(now);
}

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

function weekdayOf(date) {
  const day = new Date(`${date}T12:00:00`).getDay();
  return day === 0 ? 7 : day;
}

function addDays(date, days) {
  const d = new Date(`${date}T12:00:00`);
  d.setDate(d.getDate() + days);
  return isoDay(d);
}

async function schoolCalendar(institutionId) {
  const year = await institution.findCurrentYear(institutionId);
  if (!year) return null;
  const holidays = await institution.findHolidays(year.id);

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
