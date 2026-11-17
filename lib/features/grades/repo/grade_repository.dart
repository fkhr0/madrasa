import '../models/subject_grades_model.dart';

abstract class GradeRepository {
  Future<List<SubjectGradesModel>> getCurrentTerm(String studentId);
}
