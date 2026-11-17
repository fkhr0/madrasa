import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';

abstract class AcademicsRepository {
  Future<List<SchoolSubjectModel>> getSubjects();

  Future<void> saveSubject(SchoolSubjectModel subject);

  Future<void> deleteSubject(String subjectId);

  Future<List<SchoolClassModel>> getClasses();

  Future<void> saveClass({
    String? classId,
    required String name,
    required String? homeroomTeacherId,
    List<String> subjectIds = const [],
  });

  Future<void> deleteClass(String classId);

  Future<void> setSubjectTeacher({
    required String classId,
    required String subjectId,
    required String? teacherId,
  });

  Future<void> removeSubjectFromClass({
    required String classId,
    required String subjectId,
  });
}
