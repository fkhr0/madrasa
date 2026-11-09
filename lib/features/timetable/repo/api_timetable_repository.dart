import '../../../core/network/api_client.dart';
import '../models/class_timetable_model.dart';
import '../models/period_model.dart';
import 'timetable_repository.dart';

/// The timetable on the school API (server/src/features/timetable).
class ApiTimetableRepository implements TimetableRepository {
  final ApiClient _api;

  const ApiTimetableRepository(this._api);

  @override
  Future<List<PeriodModel>> getPeriods() async => [
    for (final json in await _api.get('/timetable/periods') as List)
      PeriodModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<void> savePeriods(
    List<PeriodModel> periods, {
    bool removeLessons = false,
  }) => _api.put('/timetable/periods', {
    'periods': [for (final p in periods) p.toJson()],
    'removeLessons': removeLessons,
  });

  @override
  Future<ClassTimetableModel> getClassTimetable(String classId) async =>
      ClassTimetableModel.fromJson(
        await _api.get('/timetable/classes/$classId') as Map<String, dynamic>,
      );

  @override
  Future<void> setLesson({
    required String classId,
    required int weekday,
    required int period,
    required String subjectId,
    required String room,
  }) => _api.put('/timetable/classes/$classId/lessons/$weekday/$period', {
    'subjectId': subjectId,
    'room': room,
  });

  @override
  Future<void> deleteLesson({
    required String classId,
    required int weekday,
    required int period,
  }) => _api.delete('/timetable/classes/$classId/lessons/$weekday/$period');

  @override
  Future<WeekTimetableModel> getWeek(String personId) async =>
      WeekTimetableModel.fromJson(
        await _api.get('/timetable/people/$personId/week')
            as Map<String, dynamic>,
      );
}
