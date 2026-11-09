import '../../subjects/data/mock_subjects.dart';
import '../models/class_student_model.dart';
import '../models/teaching_class_model.dart';

/// Mr. Ahmed Kareem's classes and students.
/// (Prep schools in Iraq are usually girls-only or boys-only per class.)
class MockTeaching {
  MockTeaching._();

  static const classes = [
    TeachingClassModel(
      id: 'cls-5a',
      name: '5th Scientific – A',
      subject: MockSubjects.math,
      room: 'Room 204',
      studentCount: 12,
      toGradeCount: 7,
    ),
    TeachingClassModel(
      id: 'cls-5b',
      name: '5th Scientific – B',
      subject: MockSubjects.math,
      room: 'Room 206',
      studentCount: 12,
      toGradeCount: 3,
    ),
    TeachingClassModel(
      id: 'cls-4a',
      name: '4th Scientific – A',
      subject: MockSubjects.math,
      room: 'Room 105',
      studentCount: 12,
    ),
    TeachingClassModel(
      id: 'cls-6c',
      name: '6th Scientific – C',
      subject: MockSubjects.math,
      room: 'Room 301',
      studentCount: 12,
      toGradeCount: 12,
    ),
  ];

  static const _girls = [
    'Zainab Haider',
    'Fatima Ali',
    'Maryam Hussein',
    'Noor Abbas',
    'Sara Mahdi',
    'Hawraa Kadhim',
    'Ruqaya Salman',
    'Zahraa Jaafar',
    'Aya Ahmed',
    'Duaa Saad',
    'Rusul Hamid',
    'Tabarak Qasim',
  ];

  static const _boys = [
    'Ali Hassan',
    'Mustafa Kareem',
    'Hussein Adel',
    'Mohammed Jabbar',
    'Abbas Fadhil',
    'Yousif Raad',
    'Ahmed Sabah',
    'Omar Nabil',
    'Hassan Muhanad',
    'Murtadha Salim',
    'Karrar Haider',
    'Sajjad Majid',
  ];

  static List<ClassStudentModel> studentsOf(String classId) {
    final names = classId == 'cls-5a' || classId == 'cls-6c' ? _girls : _boys;

    return [
      for (var i = 0; i < names.length; i++)
        ClassStudentModel(
          id: '$classId-s$i',
          name: names[i],
          // Varied but repeatable numbers.
          average: 48 + (i * 37 + classId.length * 11) % 50,
          attendanceRate: 82 + (i * 7) % 18,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }
}
