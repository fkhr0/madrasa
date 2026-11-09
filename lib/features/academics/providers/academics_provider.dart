import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';
import '../repo/academics_repository.dart';
import '../repo/api_academics_repository.dart';
import '../repo/mock_academics_repository.dart';

/// The server when API_URL is set, otherwise the mock school.
final academicsRepositoryProvider = Provider<AcademicsRepository>(
  (ref) => AppConfig.useApi
      ? ApiAcademicsRepository(watchApi(ref))
      : MockAcademicsRepository(),
);

final schoolSubjectsProvider = FutureProvider<List<SchoolSubjectModel>>((ref) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(academicsRepositoryProvider).getSubjects();
});

final schoolClassesProvider = FutureProvider<List<SchoolClassModel>>((ref) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(academicsRepositoryProvider).getClasses();
});

final schoolClassByIdProvider =
    FutureProvider.family<SchoolClassModel?, String>((ref, id) async {
      final classes = await ref.watch(schoolClassesProvider.future);

      for (final schoolClass in classes) {
        if (schoolClass.id == id) return schoolClass;
      }

      return null;
    });

/// Subjects across all classes that still have no teacher.
final unassignedSubjectsCountProvider = Provider<int>((ref) {
  final classes = ref.watch(schoolClassesProvider).valueOrNull ?? [];

  return classes.fold(0, (sum, c) => sum + c.unassignedCount);
});

final academicsActionsProvider = Provider<AcademicsActions>(
  AcademicsActions.new,
);

/// Administrator actions on subjects and classes. Each one reloads what
/// it changed. They throw ApiException with a message to show.
class AcademicsActions {
  final Ref _ref;

  AcademicsActions(this._ref);

  AcademicsRepository get _repository => _ref.read(academicsRepositoryProvider);

  Future<void> saveSubject(SchoolSubjectModel subject) async {
    await _repository.saveSubject(subject);
    _reload();
  }

  Future<void> deleteSubject(SchoolSubjectModel subject) async {
    await _repository.deleteSubject(subject.id);
    _reload();
  }

  Future<void> saveClass({
    String? classId,
    required String name,
    required String? homeroomTeacherId,
    List<String> subjectIds = const [],
  }) async {
    await _repository.saveClass(
      classId: classId,
      name: name,
      homeroomTeacherId: homeroomTeacherId,
      subjectIds: subjectIds,
    );
    _reload();
  }

  Future<void> deleteClass(SchoolClassModel schoolClass) async {
    await _repository.deleteClass(schoolClass.id);
    _reload();
  }

  /// Adds the subject to the class, or changes its teacher (null = none).
  Future<void> setSubjectTeacher({
    required String classId,
    required String subjectId,
    required String? teacherId,
  }) async {
    await _repository.setSubjectTeacher(
      classId: classId,
      subjectId: subjectId,
      teacherId: teacherId,
    );
    _reload();
  }

  Future<void> removeSubjectFromClass({
    required String classId,
    required String subjectId,
  }) async {
    await _repository.removeSubjectFromClass(
      classId: classId,
      subjectId: subjectId,
    );
    _reload();
  }

  /// Timetables show subject and teacher names, and lose the lessons of a
  /// subject removed from a class, so they reload too.
  void _reload() {
    _ref
      ..invalidate(schoolSubjectsProvider)
      ..invalidate(schoolClassesProvider)
      ..invalidate(classTimetableProvider);
  }
}
