import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';

/// Fake subjects and classes, the same as the server's demo data.
/// Teacher IDs match the People directory.
class MockSchoolClasses {
  MockSchoolClasses._();

  /// (id, name, icon, colour, usual teacher ID, teacher name)
  static const _catalogue = [
    ('math', 'Mathematics', 'math', 'purple', 'TCH-2019-0031', 'Ahmed Kareem'),
    ('physics', 'Physics', 'physics', 'blue', 'TCH-2019-0040', 'Sara Hadi'),
    (
      'chemistry',
      'Chemistry',
      'chemistry',
      'teal',
      'TCH-2019-0041',
      'Omar Saleh',
    ),
    (
      'arabic',
      'Arabic Language',
      'language',
      'orange',
      'TCH-2019-0042',
      'Huda Jaber',
    ),
    ('english', 'English', 'english', 'pink', 'TCH-2019-0043', 'Rana Sami'),
    (
      'islamic',
      'Islamic Education',
      'islamic',
      'amber',
      'TCH-2019-0044',
      'Yusuf Ali',
    ),
    ('biology', 'Biology', 'biology', 'green', 'TCH-2019-0045', 'Noor Abbas'),
    (
      'computer',
      'Computer Science',
      'computer',
      'gray',
      'TCH-2019-0046',
      'Bilal Nasser',
    ),
  ];

  static List<SchoolSubjectModel> get subjects => [
    for (final (id, name, icon, color, _, _) in _catalogue)
      SchoolSubjectModel(id: id, name: name, iconKey: icon, colorKey: color),
  ];

  /// Every subject with its usual teacher, except [without].
  static List<ClassSubjectModel> _team({List<String> without = const []}) => [
    for (final (id, name, _, _, teacherId, teacherName) in _catalogue)
      ClassSubjectModel(
        subjectId: id,
        subjectName: name,
        teacherId: without.contains(id) ? null : teacherId,
        teacherName: without.contains(id) ? null : teacherName,
      ),
  ];

  static List<SchoolClassModel> get classes => [
    SchoolClassModel(
      id: 'cls-4a',
      name: '4th Scientific – A',
      homeroomTeacherId: 'TCH-2019-0041',
      homeroomTeacherName: 'Omar Saleh',
      studentCount: 34,
      subjects: _team(),
    ),
    SchoolClassModel(
      id: 'cls-5a',
      name: '5th Scientific – A',
      homeroomTeacherId: 'TCH-2019-0042',
      homeroomTeacherName: 'Huda Jaber',
      studentCount: 32,
      subjects: _team(),
    ),
    SchoolClassModel(
      id: 'cls-5b',
      name: '5th Scientific – B',
      homeroomTeacherId: 'TCH-2019-0044',
      homeroomTeacherName: 'Yusuf Ali',
      studentCount: 30,
      // A class still being set up.
      subjects: _team(without: ['biology', 'computer']),
    ),
    SchoolClassModel(
      id: 'cls-6c',
      name: '6th Scientific – C',
      homeroomTeacherId: 'TCH-2019-0040',
      homeroomTeacherName: 'Sara Hadi',
      studentCount: 28,
      subjects: _team(),
    ),
  ];
}
