import '../../../core/network/api_client.dart';
import '../../../core/utils/day_json.dart';
import '../models/day_model.dart';
import 'day_repository.dart';

/// Days on the school API (server/src/features/days).
class ApiDayRepository implements DayRepository {
  final ApiClient _api;

  const ApiDayRepository(this._api);

  @override
  Future<DayModel> getSchoolDay(DateTime date) =>
      _get('/days/${formatDay(date)}/school');

  @override
  Future<DayModel> getTeacherDay(DateTime date) =>
      _get('/days/${formatDay(date)}/teacher');

  @override
  Future<DayModel> getStudentDay(String studentId, DateTime date) =>
      _get('/days/${formatDay(date)}/students/$studentId');

  Future<DayModel> _get(String path) async =>
      DayModel.fromJson(await _api.get(path) as Map<String, dynamic>);
}
