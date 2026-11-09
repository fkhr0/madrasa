// Dates without time, as the server sends them ("YYYY-MM-DD").

/// "2026-10-03" → 3 Oct 2026 (local midnight, no time zone shift).
DateTime parseDay(String text) => DateTime.parse(text);

/// 3 Oct 2026 → "2026-10-03"
String formatDay(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';
