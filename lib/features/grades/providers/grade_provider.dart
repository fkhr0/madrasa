import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../exams/providers/exam_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../logic/year_result.dart';
import '../models/subject_grades_model.dart';
import '../repo/api_grade_repository.dart';
import '../repo/grade_repository.dart';
import '../repo/mock_grade_repository.dart';

/// Published exam scores on the server when API_URL is set, otherwise mock.
final gradeRepositoryProvider = Provider<GradeRepository>(
  (ref) => AppConfig.useApi
      ? ApiGradeRepository(ref.watch(examRepositoryProvider))
      : const MockGradeRepository(),
);

final gradesProvider = FutureProvider<List<SubjectGradesModel>>(
  (ref) => ref
      .watch(gradeRepositoryProvider)
      .getCurrentTerm(ref.watch(activeStudentIdProvider)),
);

/// Mean of the subject averages (each subject counts the same).
final overallAverageProvider = FutureProvider<double>((ref) async {
  final subjects = await ref.watch(gradesProvider.future);
  if (subjects.isEmpty) return 0;

  final total = subjects.fold<double>(0, (sum, s) => sum + s.average);

  return total / subjects.length;
});

/// Each subject's year result (السعي السنوي and the final mark), from the
/// student's published exam scores and the study year's semesters.
final yearResultsProvider = FutureProvider<List<YearResultModel>>((ref) async {
  final exams = await ref.watch(examsProvider.future);
  final year = await ref.watch(academicYearProvider.future);
  return yearResults(exams, year.terms);
});
