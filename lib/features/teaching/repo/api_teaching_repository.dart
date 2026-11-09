import '../../../core/network/api_client.dart';
import '../../auth/models/user_model.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';
import 'teaching_repository.dart';

/// A teacher's classes and students on the school API
/// (server/src/features/teaching).
class ApiTeachingRepository implements TeachingRepository {
  final ApiClient _api;

  const ApiTeachingRepository(this._api);

  @override
  Future<List<TeachingClassModel>> getMyClasses(UserModel teacher) async => [
    for (final json in await _api.get('/teaching/classes') as List)
      TeachingClassModel.fromJson(
        json as Map<String, dynamic>,
        teacherName: teacher.name,
      ),
  ];

  @override
  Future<List<ClassStudentModel>> getStudents(String classId) async => [
    for (final json
        in await _api.get('/teaching/classes/$classId/students') as List)
      ClassStudentModel.fromJson(json as Map<String, dynamic>),
  ];
}
