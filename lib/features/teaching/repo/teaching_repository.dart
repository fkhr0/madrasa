import '../../auth/models/user_model.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';

abstract class TeachingRepository {
  Future<List<TeachingClassModel>> getMyClasses(UserModel teacher);

  Future<List<ClassStudentModel>> getStudents(String classId);
}
