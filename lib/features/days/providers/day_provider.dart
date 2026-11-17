import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/providers/clock_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/day_model.dart';
import '../repo/api_day_repository.dart';
import '../repo/day_repository.dart';
import '../repo/mock_day_repository.dart';

final dayRepositoryProvider = Provider<DayRepository>(
  (ref) => AppConfig.useApi
      ? ApiDayRepository(watchApi(ref))
      : const MockDayRepository(),
);

enum DayView { school, teacher, student }

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
