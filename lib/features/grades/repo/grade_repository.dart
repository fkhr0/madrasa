import '../models/subject_grades_model.dart';

/// Today: MockGradeRepository. Backend stage: ApiGradeRepository.
abstract class GradeRepository {
  /// Marks of the current term for [studentId], grouped by subject.
  Future<List<SubjectGradesModel>> getCurrentTerm(String studentId);
}
