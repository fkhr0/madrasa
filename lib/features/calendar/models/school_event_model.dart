import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/day_json.dart';
import 'calendar_event_model.dart';
import '../../../core/l10n/language.dart';

/// Who sees a school event.
enum EventAudience {
  everyone,

  /// Parents and staff (e.g. a parent–teacher meeting).
  families,

  /// Teachers and administrators only.
  staff;

  String get label {
    switch (this) {
      case EventAudience.everyone:
        return tr('Everyone');
      case EventAudience.families:
        return tr('Parents and staff');
      case EventAudience.staff:
        return tr('Staff only');
    }
  }
}

/// An event or meeting the administrator puts on the school calendar.
class SchoolEventModel {
  /// Empty for an event not saved yet.
  final String id;
  final String title;

  /// [CalendarEventType.event] or [CalendarEventType.meeting].
  final CalendarEventType type;
  final EventAudience audience;
  final DateTime date;

  /// Minutes after midnight (08:30 → 510); null = all day.
  final int? startMinute;

  /// Last day, for events of several days (e.g. a trip).
  final DateTime? endDate;
  final String place;
  final String details;

  const SchoolEventModel({
    required this.id,
    required this.title,
    required this.type,
    required this.audience,
    required this.date,
    this.startMinute,
    this.endDate,
    this.place = '',
    this.details = '',
  });

  DateTime get start =>
      startMinute == null ? date : date.add(Duration(minutes: startMinute!));

  factory SchoolEventModel.fromJson(Map<String, dynamic> json) {
    final time = json['time'] as String?;
    final end = json['endDate'] as String?;

    return SchoolEventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] == 'meeting'
          ? CalendarEventType.meeting
          : CalendarEventType.event,
      audience: EventAudience.values.byName(json['audience'] as String),
      date: parseDay(json['date'] as String),
      startMinute: time == null
          ? null
          : int.parse(time.substring(0, 2)) * 60 +
                int.parse(time.substring(3, 5)),
      endDate: end == null ? null : parseDay(end),
      place: json['place'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'type': type == CalendarEventType.meeting ? 'meeting' : 'event',
    'audience': audience.name,
    'date': formatDay(date),
    'time': startMinute == null
        ? null
        : '${(startMinute! ~/ 60).toString().padLeft(2, '0')}:'
              '${(startMinute! % 60).toString().padLeft(2, '0')}',
    'endDate': endDate == null ? null : formatDay(endDate!),
    'place': place,
    'details': details,
  };

  SchoolEventModel withId(String id) => SchoolEventModel(
    id: id,
    title: title,
    type: type,
    audience: audience,
    date: date,
    startMinute: startMinute,
    endDate: endDate,
    place: place,
    details: details,
  );

  /// How the calendar shows it.
  CalendarEventModel toCalendarEvent() {
    return CalendarEventModel(
      id: 'school-$id',
      title: title,
      type: type,
      start: start,
      endDay: endDate,
      isAllDay: startMinute == null,
      subtitle: [
        if (place.isNotEmpty) place,
        if (details.isNotEmpty) details,
        if (endDate != null)
          '${DateFormatter.dayMonth(date)} – ${DateFormatter.dayMonth(endDate!)}',
      ].join(' · '),
      schoolEvent: this,
    );
  }
}
