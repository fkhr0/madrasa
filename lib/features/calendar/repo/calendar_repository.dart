import '../../auth/models/user_model.dart';
import '../models/school_event_model.dart';

/// School events and meetings.
abstract class CalendarRepository {
  /// The events meant for [role] (the server decides from the signed-in user).
  Future<List<SchoolEventModel>> getSchoolEvents(UserRole role);

  // ---------- Administrator ----------
  /// Creates the event when its ID is empty, otherwise updates it.
  Future<SchoolEventModel> saveEvent(SchoolEventModel event);

  Future<void> deleteEvent(String id);
}
