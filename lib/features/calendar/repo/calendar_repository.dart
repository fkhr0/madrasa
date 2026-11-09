import '../../auth/models/user_model.dart';
import '../models/school_event_model.dart';

/// School events and meetings.
/// MockCalendarRepository (mock data) or ApiCalendarRepository (the server).
/// Holidays live in the study year; homework and exams in their features.
abstract class CalendarRepository {
  /// The events meant for [role] (the server decides from the signed-in user).
  Future<List<SchoolEventModel>> getSchoolEvents(UserRole role);

  // ---------- Administrator ----------
  /// Creates the event when its ID is empty, otherwise updates it.
  Future<SchoolEventModel> saveEvent(SchoolEventModel event);

  Future<void> deleteEvent(String id);
}
