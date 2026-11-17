class PeriodModel {
  final int number;

  final String start;
  final String end;

  const PeriodModel({
    required this.number,
    required this.start,
    required this.end,
  });

  String get label => '$start – $end';

  DateTime startOn(DateTime day) => _at(day, start);

  DateTime endOn(DateTime day) => _at(day, end);

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
