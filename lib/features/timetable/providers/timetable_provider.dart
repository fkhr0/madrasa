import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/class_timetable_model.dart';
import '../models/period_model.dart';
import '../repo/api_timetable_repository.dart';
import '../repo/mock_timetable_repository.dart';
import '../repo/timetable_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final timetableRepositoryProvider = Provider<TimetableRepository>(
  (ref) => AppConfig.useApi
      ? ApiTimetableRepository(watchApi(ref))
      : MockTimetableRepository(),
);

final periodsProvider = FutureProvider<List<PeriodModel>>((ref) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(timetableRepositoryProvider).getPeriods();
});

final classTimetableProvider =
    FutureProvider.family<ClassTimetableModel, String>((ref, classId) {
      ref.watch(authProvider.select((user) => user?.id));
      return ref.watch(timetableRepositoryProvider).getClassTimetable(classId);
    });

final timetableActionsProvider = Provider<TimetableActions>(
  TimetableActions.new,
);

/// Administrator changes to bell times and lessons. Each one reloads what
/// it changed. They throw ApiException with a message to show.
class TimetableActions {
  final Ref _ref;

  TimetableActions(this._ref);

  TimetableRepository get _repository => _ref.read(timetableRepositoryProvider);

  Future<void> savePeriods(
    List<PeriodModel> periods, {
    bool removeLessons = false,
  }) async {
    await _repository.savePeriods(periods, removeLessons: removeLessons);
    _ref
      ..invalidate(periodsProvider)
      ..invalidate(classTimetableProvider);
  }

  Future<void> setLesson({
    required String classId,
    required int weekday,
    required int period,
    required String subjectId,
    required String room,
  }) async {
    await _repository.setLesson(
      classId: classId,
      weekday: weekday,
      period: period,
      subjectId: subjectId,
      room: room,
    );
    _ref.invalidate(classTimetableProvider(classId));
  }

  Future<void> deleteLesson({
    required String classId,
    required int weekday,
    required int period,
  }) async {
    await _repository.deleteLesson(
      classId: classId,
      weekday: weekday,
      period: period,
    );
    _ref.invalidate(classTimetableProvider(classId));
  }
}
