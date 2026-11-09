import '../../../core/utils/day_json.dart';
import 'holiday_model.dart';
import 'term_model.dart';
import '../../../core/l10n/language.dart';

/// The study year set up by the school administration.
/// Everything with dates (calendar, schedule) stays inside it.
class AcademicYearModel {
  /// e.g. "2026–2027"
  final String name;
  final DateTime start;
  final DateTime end;
  final List<TermModel> terms;
  final List<HolidayModel> holidays;

  /// Days with classes, using DateTime.monday ... DateTime.sunday.
  /// Iraq: Sunday to Thursday.
  final List<int> workingDays;

  const AcademicYearModel({
    required this.name,
    required this.start,
    required this.end,
    required this.terms,
    required this.holidays,
    this.workingDays = const [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ],
  });

  /// Reads GET /academic-year.
  factory AcademicYearModel.fromJson(Map<String, dynamic> json) {
    return AcademicYearModel(
      name: json['name'] as String,
      start: parseDay(json['start'] as String),
      end: parseDay(json['end'] as String),
      workingDays: [
        for (final d in json['workingDays'] as List) (d as num).toInt(),
      ],
      terms: [
        for (final t in json['terms'] as List)
          TermModel.fromJson(t as Map<String, dynamic>),
      ],
      holidays: [
        for (final h in json['holidays'] as List)
          HolidayModel.fromJson(h as Map<String, dynamic>),
      ],
    );
  }

  AcademicYearModel copyWith({
    List<HolidayModel>? holidays,
    List<int>? workingDays,
  }) {
    return AcademicYearModel(
      name: name,
      start: start,
      end: end,
      terms: terms,
      holidays: holidays ?? this.holidays,
      workingDays: workingDays ?? this.workingDays,
    );
  }

  bool contains(DateTime day) {
    final date = _dateOnly(day);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  /// Keeps a date inside the year (used to pick the first selected day).
  DateTime clamp(DateTime day) {
    final date = _dateOnly(day);
    if (date.isBefore(start)) return start;
    if (date.isAfter(end)) return end;

    return date;
  }

  HolidayModel? holidayOn(DateTime day) {
    for (final holiday in holidays) {
      if (holiday.includes(day)) return holiday;
    }

    return null;
  }

  TermModel? termOn(DateTime day) {
    for (final term in terms) {
      if (term.includes(day)) return term;
    }

    return null;
  }

  bool isWorkingDay(DateTime day) => workingDays.contains(day.weekday);

  /// A day with classes: inside the year, a working day and not a holiday.
  bool isSchoolDay(DateTime day) =>
      contains(day) && isWorkingDay(day) && holidayOn(day) == null;

  /// Why there are no classes on [day] ("Weekend", "Eid al-Fitr"...),
  /// or null on a school day.
  String? dayOffReason(DateTime day) {
    if (!contains(day)) return tr('Outside the study year');
    final holiday = holidayOn(day);
    if (holiday != null) return holiday.name;
    if (!isWorkingDay(day)) return tr('Weekend');

    return null;
  }

  /// Today if it is a school day, otherwise the next school day of the year.
  DateTime nextSchoolDay(DateTime from) {
    var day = clamp(from);

    while (!isSchoolDay(day) && day.isBefore(end)) {
      day = day.add(const Duration(days: 1));
    }

    return day;
  }

  /// 1 for the first week of the year.
  int weekNumber(DateTime day) =>
      _dateOnly(day).difference(_weekStart(start)).inDays ~/ 7 + 1;

  int get totalWeeks => weekNumber(end);

  /// Sunday of the week [day] is in.
  static DateTime _weekStart(DateTime day) =>
      _dateOnly(day).subtract(Duration(days: day.weekday % 7));

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
