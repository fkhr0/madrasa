import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_provider.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../calendar/providers/calendar_provider.dart';
import '../../exams/providers/exam_provider.dart';
import '../../finance/providers/finance_provider.dart';
import '../../grades/providers/grade_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../../tasks/providers/task_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../logic/common_rules.dart';
import '../logic/parent_rules.dart';
import '../logic/student_rules.dart';
import '../logic/teacher_rules.dart';
import '../models/plan_tip_model.dart';
import '../../../core/l10n/language.dart';

/// The planner's tips for the signed-in user, sorted (today first).
/// Only reads data other features already load, so it costs nothing extra.
final planTipsProvider = FutureProvider<List<PlanTipModel>>((ref) async {
  final now = ref.watch(nowProvider);
  final role = ref.watch(currentUserProvider).role;
  final year = await ref.watch(academicYearProvider.future);

  final tips = [...commonTips(now: now, year: year)];

  switch (role) {
    case UserRole.student:
      tips.addAll(
        studentTips(
          now: now,
          assignments: await ref.watch(assignmentsProvider.future),
          exams: await ref.watch(examsProvider.future),
          tasks: await ref.watch(tasksProvider.future),
        ),
      );
    case UserRole.parent:
      tips.addAll(
        parentTips(
          now: now,
          childName:
              ref.watch(activeStudentProvider)?.firstName ?? tr('Your child'),
          assignments: await ref.watch(assignmentsProvider.future),
          exams: await ref.watch(examsProvider.future),
          attendance: await ref.watch(attendanceRecordsProvider.future),
          grades: await ref.watch(gradesProvider.future),
          fees: await ref.watch(
            accountProvider(ref.watch(activeStudentIdProvider)).future,
          ),
        ),
      );
    case UserRole.teacher:
      tips.addAll(
        teacherTips(
          now: now,
          classes: await ref.watch(myClassesProvider.future),
          events: await ref.watch(calendarEventsProvider.future),
        ),
      );
    case UserRole.admin:
    case UserRole.driver:
      // Their home pages have their own focused lists.
      break;
  }

  return sortTips(tips);
});
