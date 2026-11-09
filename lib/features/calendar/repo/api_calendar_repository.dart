import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';
import '../models/school_event_model.dart';
import 'calendar_repository.dart';

/// School events on the school API (server/src/features/events).
class ApiCalendarRepository implements CalendarRepository {
  final ApiClient _api;

  const ApiCalendarRepository(this._api);

  @override
  Future<List<SchoolEventModel>> getSchoolEvents(UserRole role) async {
    // The server filters by the signed-in user's role.
    final list = await _api.get('/events') as List;
    return [
      for (final json in list)
        SchoolEventModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<SchoolEventModel> saveEvent(SchoolEventModel event) async {
    final json = event.id.isEmpty
        ? await _api.post('/events', event.toJson())
        : await _api.patch('/events/${event.id}', event.toJson());
    return SchoolEventModel.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> deleteEvent(String id) => _api.delete('/events/$id');
}
