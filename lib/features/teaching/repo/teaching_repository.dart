import '../../auth/models/user_model.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';

/// A teacher's classes and their students.
/// MockTeachingRepository or ApiTeachingRepository. Attendance, exams and
/// homework have their own features.
abstract class TeachingRepository {
  Future<List<TeachingClassModel>> getMyClasses(UserModel teacher);

  /// Students of a class, sorted by name.
  Future<List<ClassStudentModel>> getStudents(String classId);
}
