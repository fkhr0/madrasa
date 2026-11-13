import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/models/user_model.dart';
import 'school_event_model.dart';
import '../../../core/l10n/language.dart';

/// Kinds of items on the calendar.
enum CalendarEventType {
  homework,
  assignment,
  quiz,
  exam,
  event,
  holiday,

  /// Parent–teacher and staff meetings (parents and teachers only).
  meeting,

  /// The student's own tasks and reminders.
  reminder;

  static List<CalendarEventType> visibleFor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return values.where((t) => t != meeting).toList();
      case UserRole.admin:
        return const [event, holiday, meeting];
      case UserRole.driver:
        return const [event, holiday];
      case UserRole.parent:
        return values.where((t) => t != reminder).toList();
      case UserRole.teacher:
        return const [event, holiday, meeting];
    }
  }

  String get label {
    switch (this) {
      case CalendarEventType.homework:
        return tr('Homework');
      case CalendarEventType.assignment:
        return tr('Assignment');
      case CalendarEventType.quiz:
        return tr('Quiz');
      case CalendarEventType.exam:
        return tr('Exam');
      case CalendarEventType.event:
        return tr('Event');
      case CalendarEventType.holiday:
        return tr('Holiday');
      case CalendarEventType.meeting:
        return tr('Meeting');
      case CalendarEventType.reminder:
        return tr('Reminder');
    }
  }

  Color get color {
    switch (this) {
      case CalendarEventType.homework:
        return AppColors.subjectTeal;
      case CalendarEventType.assignment:
        return AppColors.subjectBlue;
      case CalendarEventType.quiz:
        return AppColors.warning;
      case CalendarEventType.exam:
        return AppColors.danger;
      case CalendarEventType.event:
        return AppColors.subjectPurple;
      case CalendarEventType.holiday:
        return AppColors.success;
      case CalendarEventType.meeting:
        return AppColors.info;
      case CalendarEventType.reminder:
        return AppColors.neutral;
    }
  }

  IconData get icon {
    switch (this) {
      case CalendarEventType.homework:
        return Icons.edit_note;
      case CalendarEventType.assignment:
        return Icons.assignment_outlined;
      case CalendarEventType.quiz:
        return Icons.timer_outlined;
      case CalendarEventType.exam:
        return Icons.quiz_outlined;
      case CalendarEventType.event:
        return Icons.celebration_outlined;
      case CalendarEventType.holiday:
        return Icons.beach_access_outlined;
      case CalendarEventType.meeting:
        return Icons.groups_outlined;
      case CalendarEventType.reminder:
        return Icons.notifications_none;
    }
  }
}

/// Anything shown on the calendar.
class CalendarEventModel {
  final String id;
  final String title;
  final CalendarEventType type;
  final DateTime start;

  /// Last day for multi-day items (holidays, trips). Null for one-day items.
  final DateTime? endDay;
  final bool isAllDay;
  final String? subtitle;

  /// Where tapping the item leads, if anywhere.
  final String? route;

  /// Set for events from the school calendar (the administrator edits them).
  final SchoolEventModel? schoolEvent;

  const CalendarEventModel({
    required this.id,
    required this.title,
    required this.type,
    required this.start,
    this.endDay,
    this.isAllDay = false,
    this.subtitle,
    this.route,
    this.schoolEvent,
  });

  bool occursOn(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final first = DateTime(start.year, start.month, start.day);
    final last = endDay == null
        ? first
        : DateTime(endDay!.year, endDay!.month, endDay!.day);

    return !date.isBefore(first) && !date.isAfter(last);
  }
}
