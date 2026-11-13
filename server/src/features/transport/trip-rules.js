const { msg } = require("../../i18n");
// When a bus trip may start.

/** "2026-11-05" for a Date, in local time. */
function dayText(date) {
  const pad = (n) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Dart's weekday number: 1 = Monday … 7 = Sunday. */
function dartWeekday(date) {
  return date.getDay() === 0 ? 7 : date.getDay();
}

/**
 * Why there is no school on [date] ("Weekend", "Eid al-Fitr"…), or null.
 * [year] is { start, end, workingDays, holidays: [{ name, start, end }] }.
 */
function dayOffReason(year, date) {
  const day = dayText(date);
  if (!year || day < year.start || day > year.end) return "Outside the study year";
  if (!year.workingDays.includes(dartWeekday(date))) return "Weekend";
  const holiday = year.holidays.find((h) => day >= h.start && day <= (h.end ?? h.start));
  return holiday ? holiday.name : null;
}

/** Minutes after midnight, for a Date. */
const minuteOfDay = (date) => date.getHours() * 60 + date.getMinutes();

/**
 * Checks one trip. Returns null when it may start, else the reason.
 * Test mode skips the clock and the calendar, never the safety rules.
 */
function tripBlock({ route, direction, now, settings, year, doneToday, running }) {
  if (route.stops.length < 2) return "The line needs at least one stop.";
  if (running) return "The bus is already on a trip.";
  if (settings.testMode) return null;

  const off = dayOffReason(year, now);
  if (off) return msg("No school today ({0}).", msg(off));
  if (doneToday) return "This trip was already driven today.";

  const minutes = route.stops
    .map((s) => (direction === "toSchool" ? s.morningMinute : s.afternoonMinute))
    .sort((a, b) => a - b);
  const now_ = minuteOfDay(now);
  if (now_ < minutes[0] - settings.opensBeforeMinutes) {
    return "It is too early for this trip.";
  }
  if (now_ > minutes[minutes.length - 1] + settings.closesAfterMinutes) {
    return "It is too late for this trip.";
  }
  return null;
}

/** Metres between two GPS points. */
function distanceMetres(lat1, lng1, lat2, lng2) {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.asin(Math.sqrt(a));
}

module.exports = { dayText, dayOffReason, tripBlock, distanceMetres };
