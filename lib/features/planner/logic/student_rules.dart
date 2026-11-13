import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../assignments/models/assignment_model.dart';
import '../../exams/models/exam_model.dart';
import '../../tasks/models/task_model.dart';
import '../models/plan_tip_model.dart';
import 'common_rules.dart';
import '../../../core/l10n/language.dart';

/// The student's plan: what to do today, tomorrow and this week.
/// Plain rules, no AI, the future AI helper builds on top of these.
List<PlanTipModel> studentTips({
  required DateTime now,
  required List<AssignmentModel> assignments,
  required List<ExamModel> exams,
  required List<TaskModel> tasks,
}) {
  final tips = <PlanTipModel>[];
  final pending = assignments.where(
    (a) => a.status == AssignmentStatus.pending,
  );

  // ---------- Assignments ----------
  for (final a in pending) {
    final days = daysUntil(now, a.dueDate);
    final route = AppRoutes.assignmentDetails(a.id);
    // Judged at [now], not the phone's clock, so tips match the time given.
    final overdue = now.isAfter(a.dueDate);
    final canSubmit = !overdue || a.allowsLateSubmission;

    if (overdue) {
      tips.add(
        PlanTipModel(
          id: 'overdue-${a.id}',
          when: PlanWhen.today,
          icon: Icons.assignment_late_outlined,
          color: AppColors.danger,
          title: canSubmit
              ? tr('Hand in "{0}"', [a.title])
              : tr('"{0}" is overdue', [a.title]),
          detail: canSubmit
              ? -days == 1
                    ? tr('1 day late · late work is still accepted')
                    : tr('{0} days late · late work is still accepted', [-days])
              : tr('Late work isn\'t accepted. Talk to your teacher'),
          priority: 90,
          route: route,
        ),
      );
    } else if (days == 0) {
      tips.add(
        PlanTipModel(
          id: 'due-today-${a.id}',
          when: PlanWhen.today,
          icon: Icons.assignment_outlined,
          color: AppColors.warning,
          title: tr('Due today: {0}', [a.title]),
          detail: tr('{0} · by {1}', [
            a.subject.name,
            DateFormatter.time(a.dueDate),
          ]),
          priority: 85,
          route: route,
        ),
      );
    } else if (days == 1) {
      tips.add(
        PlanTipModel(
          id: 'due-tomorrow-${a.id}',
          when: PlanWhen.today,
          icon: Icons.edit_note,
          color: AppColors.warning,
          title: tr('Finish "{0}" tonight', [a.title]),
          detail: tr('Due tomorrow · {0}', [a.subject.name]),
          priority: 70,
          route: route,
        ),
      );
    } else if (days <= 7) {
      tips.add(
        PlanTipModel(
          id: 'due-week-${a.id}',
          when: PlanWhen.thisWeek,
          icon: Icons.assignment_outlined,
          color: AppColors.subjectBlue,
          title: tr('{0} · due {1}', [a.title, onDay(now, a.dueDate)]),
          detail: a.subject.name,
          priority: 40,
          route: route,
        ),
      );
    }
  }

  // ---------- Exams ----------
  for (final exam in exams.where((e) => now.isBefore(e.end))) {
    final days = daysUntil(now, exam.start);
    final isQuiz = exam.type == ExamType.quiz;
    final topics = exam.topics.isEmpty ? null : exam.topics.join(', ');

    if (days == 0) {
      tips.add(
        PlanTipModel(
          id: 'exam-today-${exam.id}',
          when: PlanWhen.today,
          icon: Icons.quiz_outlined,
          color: AppColors.danger,
          title: tr('{0} today: {1}', [exam.type.label, exam.subject.name]),
          detail: '${DateFormatter.time(exam.start)} · ${exam.room}',
          priority: 95,
          route: AppRoutes.exams,
        ),
      );
    } else if (days == 1) {
      tips.add(
        PlanTipModel(
          id: 'exam-tomorrow-${exam.id}',
          when: PlanWhen.today,
          icon: Icons.quiz_outlined,
          color: AppColors.danger,
          title: tr('{0} {1} tomorrow', [
            exam.subject.name,
            exam.type.label.toLowerCase(),
          ]),
          detail: topics == null
              ? tr('Review tonight')
              : tr('Review: {0}', [topics]),
          priority: isQuiz ? 72 : 80,
          route: AppRoutes.exams,
        ),
      );
    } else if (days <= 7) {
      tips.add(
        PlanTipModel(
          id: 'exam-week-${exam.id}',
          when: PlanWhen.thisWeek,
          icon: Icons.menu_book_outlined,
          color: isQuiz ? AppColors.warning : AppColors.danger,
          title: tr('Start reviewing for {0}', [exam.subject.name]),
          detail: tr('{0} in {1} days{2}', [
            exam.type.label,
            days,
            topics == null ? '' : ' · $topics',
          ]),
          // Sooner and bigger exams first.
          priority: (isQuiz ? 45 : 60) - days,
          route: AppRoutes.exams,
        ),
      );
    }
  }

  // ---------- Personal tasks ----------
  for (final task in tasks.where((t) => !t.isDone && !t.isOverdue)) {
    final days = daysUntil(now, task.dueAt);
    if (days > 1) continue;

    tips.add(
      PlanTipModel(
        id: 'task-${task.id}',
        when: days == 0 ? PlanWhen.today : PlanWhen.tomorrow,
        icon: Icons.notifications_none,
        color: task.priority.color,
        title: task.title,
        detail: tr('Reminder · {0}', [DateFormatter.time(task.dueAt)]),
        priority: days == 0 ? 60 : 50,
        route: AppRoutes.tasks,
      ),
    );
  }

  // ---------- A busy tomorrow ----------
  final examsTomorrow = exams.where(
    (e) => now.isBefore(e.end) && daysUntil(now, e.start) == 1,
  );
  final dueTomorrow = pending.where((a) => daysUntil(now, a.dueDate) == 1);
  final load = examsTomorrow.length + dueTomorrow.length;

  if (load >= 2) {
    tips.add(
      PlanTipModel(
        id: 'busy-tomorrow',
        when: PlanWhen.today,
        icon: Icons.event_busy_outlined,
        color: AppColors.subjectPurple,
        title: tr('Tomorrow is a busy day'),
        detail: tr('{0} and {1}: plan your evening', [
          examsTomorrow.length == 1
              ? tr('1 exam')
              : tr('{0} exams', [examsTomorrow.length]),
          dueTomorrow.length == 1
              ? tr('1 deadline')
              : tr('{0} deadlines', [dueTomorrow.length]),
        ]),
        priority: 75,
      ),
    );
  }

  return tips;
}
