/// One bell period of the school day, e.g. period 2 from 08:50 to 09:35.
/// The same for every class of the school.
class PeriodModel {
  /// 1, 2, 3... in the order of the day.
  final int number;

  /// "08:50" (24-hour, as the server sends it).
  final String start;
  final String end;

  const PeriodModel({
    required this.number,
    required this.start,
    required this.end,
  });

  /// "08:50 – 09:35"
  String get label => '$start – $end';

  /// The start on [day], e.g. 4 Nov 2026 08:50.
  DateTime startOn(DateTime day) => _at(day, start);

  DateTime endOn(DateTime day) => _at(day, end);

  /// Minutes after midnight, for comparing times.
  int get startMinutes => _minutes(start);
  int get endMinutes => _minutes(end);

  static int _minutes(String time) {
    final [hour, minute] = time.split(':').map(int.parse).toList();
    return hour * 60 + minute;
  }

  static DateTime _at(DateTime day, String time) {
    final minutes = _minutes(time);
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  factory PeriodModel.fromJson(Map<String, dynamic> json) => PeriodModel(
    number: json['number'] as int,
    start: json['start'] as String,
    end: json['end'] as String,
  );

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
}
