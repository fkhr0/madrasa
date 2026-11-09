import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../institution/models/academic_year_model.dart';
import '../models/plan_tip_model.dart';
import '../../../core/l10n/language.dart';

/// Whole days from [now]'s date to [date]'s date (0 = same day).
int daysUntil(DateTime now, DateTime date) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(date.year, date.month, date.day);

  return b.difference(a).inDays;
}

/// "on Thursday" within a week, otherwise "on 12 Jan".
String onDay(DateTime now, DateTime date) {
  final days = daysUntil(now, date);
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days < 7) return tr('on {0}', [DateFormatter.weekday(date)]);

  return tr('on {0}', [DateFormatter.dayMonth(date)]);
}

/// Rules every role shares.
List<PlanTipModel> commonTips({
  required DateTime now,
  required AcademicYearModel year,
}) {
  final tips = <PlanTipModel>[];

  // A holiday in the coming week (helps plan around it).
  for (final holiday in year.holidays) {
    final days = daysUntil(now, holiday.start);
    if (days < 1 || days > 7) continue;

    tips.add(
      PlanTipModel(
        id: 'holiday-${holiday.start}',
        when: PlanWhen.thisWeek,
        icon: holiday.type.icon,
        color: AppColors.success,
        title: tr('No school {0}', [onDay(now, holiday.start)]),
        detail: holiday.lengthInDays > 1
            ? tr('{0} · {1} days off', [holiday.name, holiday.lengthInDays])
            : holiday.name,
        priority: 20,
        route: AppRoutes.calendar,
      ),
    );
  }

  return tips;
}
