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

final overallAverageProvider = FutureProvider<double?>((ref) async {
  final graded = (await ref.watch(
    gradesProvider.future,
  )).where((s) => s.hasMarks).toList();
  if (graded.isEmpty) return null;

  final total = graded.fold<double>(0, (sum, s) => sum + s.average);

  return total / graded.length;
});

final yearResultsProvider = FutureProvider<List<YearResultModel>>((ref) async {
  final exams = await ref.watch(examsProvider.future);
  final year = await ref.watch(academicYearProvider.future);
  return yearResults(exams, year.terms);
});
