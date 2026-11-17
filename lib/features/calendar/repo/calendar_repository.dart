import '../../auth/models/user_model.dart';
import '../models/school_event_model.dart';

abstract class CalendarRepository {
  Future<List<SchoolEventModel>> getSchoolEvents(UserRole role);

  Future<SchoolEventModel> saveEvent(SchoolEventModel event);

  Future<void> deleteEvent(String id);
}
