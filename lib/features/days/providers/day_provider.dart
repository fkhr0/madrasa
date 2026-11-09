import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/providers/clock_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/day_model.dart';
import '../repo/api_day_repository.dart';
import '../repo/day_repository.dart';
import '../repo/mock_day_repository.dart';

/// The server when API_URL is set, otherwise the mock timetable.
final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => AppConfig.useApi
      ? ApiDayRepository(watchApi(ref))
      : const MockDayRepository(),
);

/// Whose day: the whole school, a teacher's, or a student's.
enum DayView { school, teacher, student }

/// A day for a view. Today's reloads with the 15-second clock, so "now"
/// and attendance coming in show by themselves.
final dayProvider =
    FutureProvider.family<DayModel, (DayView, String?, DateTime)>((ref, key) {
      ref.watch(authProvider.select((user) => user?.id));
      final (view, studentId, date) = key;
      final now = DateTime.now();
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        ref.watch(clockProvider);
      }
      final repository = ref.watch(dayRepositoryProvider);
      return switch (view) {
        DayView.school => repository.getSchoolDay(date),
        DayView.teacher => repository.getTeacherDay(date),
        DayView.student => repository.getStudentDay(studentId!, date),
      };
    });
