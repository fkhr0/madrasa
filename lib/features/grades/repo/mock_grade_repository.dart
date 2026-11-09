import '../data/mock_grades.dart';
import '../models/subject_grades_model.dart';
import 'grade_repository.dart';

class MockGradeRepository implements GradeRepository {
  const MockGradeRepository();

  @override
  Future<List<SubjectGradesModel>> getCurrentTerm(String studentId) async =>
      MockGrades.forStudent(studentId);
}
