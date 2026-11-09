import '../../auth/models/user_model.dart';
import '../data/mock_calendar_events.dart';
import '../models/school_event_model.dart';
import 'calendar_repository.dart';

/// Keeps events in memory, so the administrator's changes last the session.
class MockCalendarRepository implements CalendarRepository {
  final List<SchoolEventModel> _events = MockCalendarEvents.items;
  int _count = 0;

  @override
  Future<List<SchoolEventModel>> getSchoolEvents(UserRole role) async {
    final audiences = switch (role) {
      UserRole.student || UserRole.driver => const [EventAudience.everyone],
      UserRole.parent => const [EventAudience.everyone, EventAudience.families],
      UserRole.teacher || UserRole.admin => EventAudience.values,
    };

    return _events.where((e) => audiences.contains(e.audience)).toList();
  }

  @override
  Future<SchoolEventModel> saveEvent(SchoolEventModel event) async {
    if (event.id.isEmpty) {
      final saved = event.withId('new-${++_count}');
      _events.add(saved);
      return saved;
    }

    final index = _events.indexWhere((e) => e.id == event.id);
    _events[index] = event;
    return event;
  }

  @override
  Future<void> deleteEvent(String id) async {
    _events.removeWhere((e) => e.id == id);
  }
}
