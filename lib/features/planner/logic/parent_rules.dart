import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../assignments/models/assignment_model.dart';
import '../../attendance/models/attendance_record_model.dart';
import '../../exams/models/exam_model.dart';
import '../../finance/models/student_account_model.dart';
import '../../grades/models/subject_grades_model.dart';
import '../models/plan_tip_model.dart';
import 'common_rules.dart';
import '../../../core/l10n/language.dart';

/// What a parent may want to know or act on for one child.
/// Calm on purpose: only things worth a parent's attention.
List<PlanTipModel> parentTips({
  required DateTime now,
  required String childName,
  required List<AssignmentModel> assignments,
  required List<ExamModel> exams,
  required List<AttendanceRecordModel> attendance,
  required List<SubjectGradesModel> grades,
  StudentAccountModel? fees,
}) {
  final tips = <PlanTipModel>[];

  // School fees: overdue, or the next installment within a week.
  if (fees != null) {
    final overdue = fees.overdueAmount(now);
    final next = fees.nextDue();

    if (overdue > 0) {
      tips.add(
        PlanTipModel(
          id: 'fees-overdue',
          when: PlanWhen.today,
          icon: Icons.payments_outlined,
          color: AppColors.danger,
          title: tr('{0} of school fees is overdue', [
            MoneyFormatter.iqd(overdue),
          ]),
          detail: tr('For {0} · pay at the office or by transfer', [childName]),
          priority: 70,
          route: AppRoutes.fees,
        ),
      );
    } else if (next != null && daysUntil(now, next.$1.dueDate) <= 7) {
      tips.add(
        PlanTipModel(
          id: 'fees-next',
          when: PlanWhen.thisWeek,
          icon: Icons.payments_outlined,
          color: AppColors.warning,
          title: tr('{0} due {1}', [next.$1.name, onDay(now, next.$1.dueDate)]),
          detail: tr('{0} for {1}', [MoneyFormatter.iqd(next.$2), childName]),
          priority: 50,
          route: AppRoutes.fees,
        ),
      );
    }
  }

  // Absences in the last 7 days.
  final recentAbsences = attendance.where(
    (r) => r.status == AttendanceStatus.absent && daysUntil(r.date, now) <= 7,
  );
  for (final r in recentAbsences) {
    tips.add(
      PlanTipModel(
        id: 'absent-${r.date}',
        when: PlanWhen.today,
        icon: Icons.event_busy_outlined,
        color: AppColors.danger,
        title: tr('{0} was absent {1}', [childName, _pastDay(now, r.date)]),
        detail: tr('Let the school know if this is unexpected'),
        priority: 90 - daysUntil(r.date, now),
        route: AppRoutes.attendance,
      ),
    );
  }

  // Exams in the next 3 days.
  for (final exam in exams.where((e) => now.isBefore(e.end))) {
    final days = daysUntil(now, exam.start);
    if (days > 3) continue;

    tips.add(
      PlanTipModel(
        id: 'exam-${exam.id}',
        when: days <= 1 ? PlanWhen.today : PlanWhen.thisWeek,
        icon: Icons.quiz_outlined,
        color: AppColors.warning,
        title: tr('{0} has a {1} {2} {3}', [
          childName,
          exam.subject.name,
          exam.type.label.toLowerCase(),
          onDay(now, exam.start),
        ]),
        detail: days <= 1
            ? tr('A calm evening of review helps')
            : DateFormatter.time(exam.start),
        priority: 80 - days * 5,
        route: AppRoutes.exams,
      ),
    );
  }

  // Overdue work.
  // Judged at [now], not the phone's clock.
  final overdue = assignments
      .where(
        (a) => a.status == AssignmentStatus.pending && now.isAfter(a.dueDate),
      )
      .toList();
  if (overdue.isNotEmpty) {
    tips.add(
      PlanTipModel(
        id: 'overdue',
        when: PlanWhen.today,
        icon: Icons.assignment_late_outlined,
        color: AppColors.warning,
        title: overdue.length == 1
            ? tr('{0} has 1 overdue assignment', [childName])
            : tr('{0} has {1} overdue assignments', [
                childName,
                overdue.length,
              ]),
        detail: overdue.map((a) => a.title).join(' · '),
        priority: 70,
        route: AppRoutes.work,
      ),
    );
  }

  // Subjects in the "Average" band or lower.
  for (final g in grades.where((g) => g.average < 60)) {
    tips.add(
      PlanTipModel(
        id: 'low-${g.subject.id}',
        when: PlanWhen.thisWeek,
        icon: Icons.trending_down,
        color: AppColors.warning,
        title: tr('{0}: average {1}', [g.subject.name, g.average.round()]),
        detail: tr('Consider a word with {0}', [g.subject.teacherName]),
        priority: 50,
        route: AppRoutes.grades,
      ),
    );
  }

  return tips;
}

String _pastDay(DateTime now, DateTime date) {
  final days = daysUntil(date, now);
  if (days == 0) return 'today';
  if (days == 1) return 'yesterday';

  return tr('on {0}', [DateFormatter.weekday(date)]);
}
