import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/exam_model.dart';
import '../repo/api_exam_repository.dart';
import '../repo/exam_repository.dart';
import '../repo/mock_exam_repository.dart';

final examRepositoryProvider = Provider<ExamRepository>(
  (ref) => AppConfig.useApi
      ? ApiExamRepository(watchApi(ref))
      : MockExamRepository(),
);

final studentExamsProvider = FutureProvider.family<List<ExamModel>, String>((
  ref,
  studentId,
) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(examRepositoryProvider).getCurrentTerm(studentId);
});

final examsProvider = FutureProvider<List<ExamModel>>(
  (ref) => ref.watch(
    studentExamsProvider(ref.watch(activeStudentIdProvider)).future,
  ),
);

final upcomingExamsProvider = FutureProvider<List<ExamModel>>((ref) async {
  final all = await ref.watch(examsProvider.future);

  return all.where((e) => e.isUpcoming).toList();
});

final pastExamsProvider = FutureProvider<List<ExamModel>>((ref) async {
  final all = await ref.watch(examsProvider.future);

  return all.where((e) => !e.isUpcoming).toList().reversed.toList();
});

final classExamsProvider = FutureProvider.family<List<ExamModel>, String>(
  (ref, classId) => ref.watch(examRepositoryProvider).getClassExams(classId),
);

final scoreSheetProvider =
    FutureProvider.family<(ExamModel, List<StudentScoreModel>), String>(
      (ref, examId) => ref.watch(examRepositoryProvider).getScoreSheet(examId),
    );

final examActionsProvider = Provider<ExamActions>(ExamActions.new);

class ExamActions {
  final Ref _ref;

  ExamActions(this._ref);

  ExamRepository get _repository => _ref.read(examRepositoryProvider);

  Future<void> saveExam(ExamDraftModel draft, {String? examId}) async {
    await _repository.saveExam(draft, examId: examId);
    _reload(draft.classId);
    if (examId != null) _ref.invalidate(scoreSheetProvider(examId));
  }

  Future<void> deleteExam(ExamModel exam) async {
    await _repository.deleteExam(exam.id);
    _reload(exam.classId);
  }

  Future<void> saveScores(ExamModel exam, Map<String, double?> scores) async {
    await _repository.saveScores(exam.id, scores);
    _reload(exam.classId);
    _ref
      ..invalidate(scoreSheetProvider(exam.id))
      ..invalidate(classStudentsProvider(exam.classId))
      ..invalidate(myClassesProvider);
  }

  void _reload(String classId) => _ref
    ..invalidate(classExamsProvider(classId))
    ..invalidate(studentExamsProvider);
}
