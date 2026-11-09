import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';

/// Subjects, classes, head teachers and subject teachers, managed by the
/// administrator. MockAcademicsRepository or ApiAcademicsRepository.
abstract class AcademicsRepository {
  // ---------- Subjects ----------
  Future<List<SchoolSubjectModel>> getSubjects();

  /// Creates the subject when its ID is empty, otherwise updates it.
  Future<void> saveSubject(SchoolSubjectModel subject);

  /// Also removes it from every class.
  Future<void> deleteSubject(String subjectId);

  // ---------- Classes ----------
  Future<List<SchoolClassModel>> getClasses();

  /// A new class with [subjectIds], or (with an ID) a new name or head
  /// teacher. Throws when the name is already used.
  Future<void> saveClass({
    String? classId,
    required String name,
    required String? homeroomTeacherId,
    List<String> subjectIds = const [],
  });

  /// Refused while the class has students.
  Future<void> deleteClass(String classId);

  /// Adds the subject to the class, or changes its teacher (null = none).
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
