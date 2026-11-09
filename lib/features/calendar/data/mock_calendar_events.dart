import '../models/calendar_event_model.dart';
import '../models/school_event_model.dart';

/// School events, close to today so the calendar always has something.
/// Holidays come from the academic year; homework, exams and reminders are
/// added by the calendar provider.
class MockCalendarEvents {
  MockCalendarEvents._();

  static DateTime _day(int offset) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset);
  }

  static List<SchoolEventModel> get items => [
    SchoolEventModel(
      id: 'ev4',
      title: 'Sports day',
      type: CalendarEventType.event,
      audience: EventAudience.everyone,
      date: _day(-6),
      startMinute: 9 * 60,
      place: 'School playground',
    ),
    SchoolEventModel(
      id: 'ev1',
      title: 'Class photo day',
      type: CalendarEventType.event,
      audience: EventAudience.everyone,
      date: _day(1),
      startMinute: 8 * 60 + 30,
      details: 'Wear the full uniform',
    ),
    SchoolEventModel(
      id: 'mt2',
      title: 'Mathematics department meeting',
      type: CalendarEventType.meeting,
      audience: EventAudience.staff,
      date: _day(2),
      startMinute: 13 * 60 + 30,
      place: 'Staff room',
    ),
    SchoolEventModel(
      id: 'mt1',
      title: 'Parent–teacher meeting',
      type: CalendarEventType.meeting,
      audience: EventAudience.families,
      date: _day(4),
      startMinute: 14 * 60,
      place: 'Main hall',
      details: '2:00 – 5:00 pm, by class',
    ),
    SchoolEventModel(
      id: 'ev2',
      title: 'Science fair',
      type: CalendarEventType.event,
      audience: EventAudience.everyone,
      date: _day(11),
      startMinute: 9 * 60,
      place: 'School courtyard',
    ),
    SchoolEventModel(
      id: 'ev3',
      title: 'Trip to the Iraq Natural History Museum',
      type: CalendarEventType.event,
      audience: EventAudience.everyone,
      date: _day(20),
      startMinute: 8 * 60,
      details: 'Bring the signed permission slip',
    ),
  ];
}
