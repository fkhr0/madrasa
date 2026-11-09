import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../calendar/models/calendar_event_model.dart';
import '../../teaching/models/teaching_class_model.dart';
import '../models/plan_tip_model.dart';
import 'common_rules.dart';
import '../../../core/l10n/language.dart';

/// The teacher's plan: grading, meetings, and what's coming.
List<PlanTipModel> teacherTips({
  required DateTime now,
  required List<TeachingClassModel> classes,
  required List<CalendarEventModel> events,
}) {
  final tips = <PlanTipModel>[];

  // Work waiting to be graded, biggest pile first.
  for (final c in classes.where((c) => c.toGradeCount > 0)) {
    tips.add(
      PlanTipModel(
        id: 'grade-${c.id}',
        when: PlanWhen.today,
        icon: Icons.rate_review_outlined,
        color: AppColors.warning,
        title: tr('{0} submissions to grade', [c.toGradeCount]),
        detail: c.name,
        priority: 50 + c.toGradeCount.clamp(0, 30),
        route: AppRoutes.classDetails(c.id),
      ),
    );
  }

  // Meetings in the next 3 days.
  for (final e in events.where((e) => e.type == CalendarEventType.meeting)) {
    final days = daysUntil(now, e.start);
    if (days < 0 || days > 3) continue;

    tips.add(
      PlanTipModel(
        id: 'meeting-${e.id}',
        when: days == 0
            ? PlanWhen.today
            : days == 1
            ? PlanWhen.tomorrow
            : PlanWhen.thisWeek,
        icon: Icons.groups_outlined,
        color: AppColors.info,
        title: e.title,
        detail: tr('{0} at {1}{2}', [
          onDay(now, e.start),
          DateFormatter.time(e.start),
          e.subtitle == null ? '' : ' · ${e.subtitle}',
        ]),
        priority: 65,
        route: AppRoutes.calendar,
      ),
    );
  }

  return tips;
}
