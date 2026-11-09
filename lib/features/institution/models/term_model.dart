import '../../../core/utils/day_json.dart';

/// A semester (school) or course term (university).
class TermModel {
  final String name;
  final DateTime start;
  final DateTime end;

  const TermModel({required this.name, required this.start, required this.end});

  factory TermModel.fromJson(Map<String, dynamic> json) => TermModel(
    name: json['name'] as String,
    start: parseDay(json['start'] as String),
    end: parseDay(json['end'] as String),
  );

  bool includes(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(start) && !date.isAfter(end);
  }
}
