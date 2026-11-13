import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../academics/providers/academics_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';
import '../repo/api_teaching_repository.dart';
import '../repo/mock_teaching_repository.dart';
import '../repo/teaching_repository.dart';

/// The server when API_URL is set, otherwise the mock classes.
final teachingRepositoryProvider = Provider<TeachingRepository>(
  (ref) => AppConfig.useApi
      ? ApiTeachingRepository(watchApi(ref))
      : const MockTeachingRepository(),
);

final myClassesProvider = FutureProvider<List<TeachingClassModel>>(
  (ref) => ref
      .watch(teachingRepositoryProvider)
      .getMyClasses(ref.watch(currentUserProvider)),
);

final classByIdProvider = FutureProvider.family<TeachingClassModel?, String>((
  ref,
  id,
) async {
  final classes = await ref.watch(myClassesProvider.future);

  for (final teachingClass in classes) {
    if (teachingClass.id == id) return teachingClass;
  }

  return null;
});

final classStudentsProvider =
    FutureProvider.family<List<ClassStudentModel>, String>(
      (ref, classId) =>
          ref.watch(teachingRepositoryProvider).getStudents(classId),
    );

/// A class's name and the subjects this user may set exams and homework for, as
/// (id, name): every subject for the office, the teacher's own subject for a
/// teacher.
final classSubjectChoicesProvider =
    Provider.family<(String, List<(String, String)>), String>((ref, classId) {
      if (ref.watch(currentUserProvider).role == UserRole.admin) {
        final c = ref.watch(schoolClassByIdProvider(classId)).valueOrNull;
        return (
          c?.name ?? '',
          [
            for (final s in c?.subjects ?? const [])
              (s.subjectId, s.subjectName),
          ],
        );
      }
      final c = ref.watch(classByIdProvider(classId)).valueOrNull;
      return (c?.name ?? '', [if (c != null) (c.subject.id, c.subject.name)]);
    });
