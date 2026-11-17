import '../../subjects/models/subject_model.dart';

class LessonModel {
  final String id;
  final SubjectModel subject;
  final String room;
  final DateTime start;
  final DateTime end;

  final String? className;

  const LessonModel({
    required this.id,
    required this.subject,
    required this.room,
    required this.start,
    required this.end,
    this.className,
  });

  bool get isNow {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(end);
  }

  bool get isOver => DateTime.now().isAfter(end);

  int get durationMinutes => end.difference(start).inMinutes;
}
