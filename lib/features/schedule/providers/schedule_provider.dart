import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/config/app_config.dart';
import '../../institution/providers/institution_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../models/lesson_model.dart';
import '../repo/api_schedule_repository.dart';
import '../repo/mock_schedule_repository.dart';
import '../repo/schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => AppConfig.useApi
      ? ApiScheduleRepository(ref.watch(timetableRepositoryProvider))
      : const MockScheduleRepository(),
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

final lessonsForDayProvider =
    FutureProvider.family<List<LessonModel>, DateTime>((ref, day) async {
      final year = await ref.watch(academicYearProvider.future);
      if (!year.isSchoolDay(day)) return [];

      final user = ref.watch(currentUserProvider);
      final personId = user.role == UserRole.teacher
          ? user.id
          : ref.watch(activeStudentIdProvider);

      return ref.watch(scheduleRepositoryProvider).getLessonsFor(personId, day);
    });

final todayLessonsProvider = FutureProvider<List<LessonModel>>(
  (ref) => ref.watch(lessonsForDayProvider(_today()).future),
);
