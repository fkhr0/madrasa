import '../../../core/network/api_exception.dart';
import '../../auth/models/user_model.dart';
import '../../people/data/mock_people.dart';
import '../data/mock_school_classes.dart';
import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';
import 'academics_repository.dart';

/// Keeps subjects and classes in memory and follows the server's rules (unique
/// names, no deleting a class with students), so the screens behave the same
/// without a server.
class MockAcademicsRepository implements AcademicsRepository {
  final List<SchoolSubjectModel> _subjects = MockSchoolClasses.subjects;
  final List<SchoolClassModel> _classes = MockSchoolClasses.classes;
  int _count = 0;

  String? _teacherName(String? id) {
    if (id == null) return null;
    for (final u in MockPeople.all) {
      if (u.id == id && u.role == UserRole.teacher) return u.name;
    }
    return null;
  }

  // ---------- Subjects ----------

  @override
  Future<List<SchoolSubjectModel>> getSubjects() async => [
    for (final s in _subjects)
      s.copyWith(
        classCount: _classes
            .where((c) => c.subjects.any((cs) => cs.subjectId == s.id))
            .length,
      ),
  ]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> saveSubject(SchoolSubjectModel subject) async {
    _checkUnique(
      subject.name,
      _subjects.where((s) => s.id != subject.id).map((s) => s.name),
    );

    if (subject.id.isEmpty) {
      _subjects.add(subject.copyWith(id: 'subject-${++_count}'));
      return;
    }
    final index = _subjects.indexWhere((s) => s.id == subject.id);
    _subjects[index] = subject;

    // Classes show the subject's name: keep it up to date.
    for (var i = 0; i < _classes.length; i++) {
      _classes[i] = _withSubjects(_classes[i], [
        for (final cs in _classes[i].subjects)
          cs.subjectId == subject.id
              ? ClassSubjectModel(
                  subjectId: cs.subjectId,
                  subjectName: subject.name,
                  teacherId: cs.teacherId,
                  teacherName: cs.teacherName,
                )
              : cs,
      ]);
    }
  }

  @override
  Future<void> deleteSubject(String subjectId) async {
    _subjects.removeWhere((s) => s.id == subjectId);
    for (var i = 0; i < _classes.length; i++) {
      _classes[i] = _withSubjects(
        _classes[i],
        _classes[i].subjects.where((cs) => cs.subjectId != subjectId).toList(),
      );
    }
  }

  // ---------- Classes ----------

  @override
  Future<List<SchoolClassModel>> getClasses() async =>
      [..._classes]..sort((a, b) => a.name.compareTo(b.name));

  @override
  Future<void> saveClass({
    String? classId,
    required String name,
    required String? homeroomTeacherId,
    List<String> subjectIds = const [],
  }) async {
    _checkUnique(
      name,
      _classes.where((c) => c.id != classId).map((c) => c.name),
    );

    if (classId == null) {
      _classes.add(
        SchoolClassModel(
          id: 'class-${++_count}',
          name: name,
          homeroomTeacherId: homeroomTeacherId,
          homeroomTeacherName: _teacherName(homeroomTeacherId),
          subjects: [
            for (final s in _subjects.where((s) => subjectIds.contains(s.id)))
              ClassSubjectModel(subjectId: s.id, subjectName: s.name),
          ],
        ),
      );
      return;
    }

    final index = _classes.indexWhere((c) => c.id == classId);
    final old = _classes[index];
    _classes[index] = SchoolClassModel(
      id: old.id,
      name: name,
      homeroomTeacherId: homeroomTeacherId,
      homeroomTeacherName: _teacherName(homeroomTeacherId),
      studentCount: old.studentCount,
      subjects: old.subjects,
    );
  }

  @override
  Future<void> deleteClass(String classId) async {
    final schoolClass = _classes.firstWhere((c) => c.id == classId);
    if (schoolClass.studentCount > 0) {
      throw ApiException(
        '${schoolClass.name} has ${schoolClass.studentCount} students. '
        'Move them to another class first.',
        status: 409,
      );
    }
    _classes.remove(schoolClass);
  }

  @override
  Future<void> setSubjectTeacher({
    required String classId,
    required String subjectId,
    required String? teacherId,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    final subject = _subjects.firstWhere((s) => s.id == subjectId);
    final updated = ClassSubjectModel(
      subjectId: subjectId,
      subjectName: subject.name,
      teacherId: teacherId,
      teacherName: _teacherName(teacherId),
    );
    final subjects = _classes[index].subjects;

    _classes[index] = _withSubjects(
      _classes[index],
      subjects.any((cs) => cs.subjectId == subjectId)
          ? [
              for (final cs in subjects)
                cs.subjectId == subjectId ? updated : cs,
            ]
          : [...subjects, updated],
    );
  }

  @override
  Future<void> removeSubjectFromClass({
    required String classId,
    required String subjectId,
  }) async {
    final index = _classes.indexWhere((c) => c.id == classId);
    _classes[index] = _withSubjects(
      _classes[index],
      _classes[index].subjects
          .where((cs) => cs.subjectId != subjectId)
          .toList(),
    );
  }

  // ---------- helpers ----------

  static SchoolClassModel _withSubjects(
    SchoolClassModel c,
    List<ClassSubjectModel> subjects,
  ) => SchoolClassModel(
    id: c.id,
    name: c.name,
    homeroomTeacherId: c.homeroomTeacherId,
    homeroomTeacherName: c.homeroomTeacherName,
    studentCount: c.studentCount,
    subjects: subjects,
  );

  static void _checkUnique(String name, Iterable<String> others) {
    final wanted = name.trim().toLowerCase();
    if (others.any((n) => n.trim().toLowerCase() == wanted)) {
      throw const ApiException(
        'That name is already used. Choose another.',
        status: 409,
      );
    }
  }
}
