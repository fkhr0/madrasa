import '../../auth/models/user_model.dart';
import '../data/mock_teaching.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';
import 'teaching_repository.dart';

/// Mr. Ahmed's mock classes and students.
class MockTeachingRepository implements TeachingRepository {
  const MockTeachingRepository();

  @override
  Future<List<TeachingClassModel>> getMyClasses(UserModel teacher) async =>
      MockTeaching.classes;

  @override
  Future<List<ClassStudentModel>> getStudents(String classId) async =>
      MockTeaching.studentsOf(classId);
}
