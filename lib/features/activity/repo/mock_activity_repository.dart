import '../../../core/utils/date_formatter.dart';
import '../models/activity_item_model.dart';
import 'activity_repository.dart';

/// A few lines of a school day, for mock mode.
class MockActivityRepository implements ActivityRepository {
  const MockActivityRepository();

  static DateTime _ago(int minutes) =>
      DateTime.now().subtract(Duration(minutes: minutes));

  static final _items = [
    ActivityItemModel(
      id: 'm1',
      at: _ago(18),
      actorName: 'Ahmed Kareem',
      actorRole: 'teacher',
      kind: ActivityKind.attendance,
      action: 'attendance.taken',
      summary:
          'Ahmed Kareem took attendance for 5th Scientific – A, period 2 '
          '(Mathematics): 30 present, 1 late, 1 absent',
      className: '5th Scientific – A',
    ),
    ActivityItemModel(
      id: 'm2',
      at: _ago(65),
      actorName: 'Huda Jaber',
      actorRole: 'teacher',
      kind: ActivityKind.grades,
      action: 'exam.scored',
      summary:
          'Huda Jaber published Poetry analysis scores (Arabic Language) '
          'for 5th Scientific – B',
      className: '5th Scientific – B',
    ),
    ActivityItemModel(
      id: 'm3',
      at: _ago(120),
      actorName: 'Omar Saleh',
      actorRole: 'teacher',
      kind: ActivityKind.homework,
      action: 'homework.set',
      summary:
          'Omar Saleh set "Lab report: rates of reaction" (Chemistry) for '
          '5th Scientific – A',
      className: '5th Scientific – A',
    ),
    ActivityItemModel(
      id: 'm4',
      at: _ago(240),
      actorName: 'School Office',
      actorRole: 'admin',
      kind: ActivityKind.finance,
      action: 'payment.recorded',
      summary: 'School Office recorded 875,000 IQD for Zainab Haider',
    ),
    ActivityItemModel(
      id: 'm5',
      at: _ago(300),
      actorName: 'School Office',
      actorRole: 'admin',
      kind: ActivityKind.announcement,
      action: 'announcement.posted',
      summary: 'School Office posted "Mid-term exams timetable published"',
    ),
  ];

  @override
  Future<ActivityPageModel> list(
    ActivityFilter filter, {
    DateTime? before,
    int limit = 30,
  }) async {
    final query = filter.query.toLowerCase();
    final items = _items
        .where(
          (i) =>
              (filter.date == null ||
                  DateFormatter.isSameDay(i.at, filter.date!)) &&
              (filter.kinds.isEmpty || filter.kinds.contains(i.kind)) &&
              (query.isEmpty || i.summary.toLowerCase().contains(query)) &&
              (before == null || i.at.isBefore(before)),
        )
        .take(limit)
        .toList();
    return ActivityPageModel(items: items);
  }
}
