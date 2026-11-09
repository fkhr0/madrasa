import '../../../core/network/api_client.dart';
import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';
import 'academics_repository.dart';

/// Academics on the school API (server/src/features/academics).
class ApiAcademicsRepository implements AcademicsRepository {
  final ApiClient _api;

  const ApiAcademicsRepository(this._api);

  @override
  Future<List<SchoolSubjectModel>> getSubjects() async => [
    for (final json in await _api.get('/academics/subjects') as List)
      SchoolSubjectModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<void> saveSubject(SchoolSubjectModel subject) => subject.id.isEmpty
      ? _api.post('/academics/subjects', subject.toJson())
      : _api.patch('/academics/subjects/${subject.id}', subject.toJson());

  @override
  Future<void> deleteSubject(String subjectId) =>
      _api.delete('/academics/subjects/$subjectId');

  @override
  Future<List<SchoolClassModel>> getClasses() async => [
    for (final json in await _api.get('/academics/classes') as List)
      SchoolClassModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<void> saveClass({
    String? classId,
    required String name,
    required String? homeroomTeacherId,
    List<String> subjectIds = const [],
  }) {
    final body = {'name': name, 'homeroomTeacherId': homeroomTeacherId};

    return classId == null
        ? _api.post('/academics/classes', {...body, 'subjectIds': subjectIds})
        : _api.patch('/academics/classes/$classId', body);
  }

  @override
  Future<void> deleteClass(String classId) =>
      _api.delete('/academics/classes/$classId');

  @override
  Future<void> setSubjectTeacher({
    required String classId,
    required String subjectId,
    required String? teacherId,
  }) => _api.put('/academics/classes/$classId/subjects/$subjectId', {
    'teacherId': teacherId,
  });

  @override
  Future<void> removeSubjectFromClass({
    required String classId,
    required String subjectId,
  }) => _api.delete('/academics/classes/$classId/subjects/$subjectId');
}
