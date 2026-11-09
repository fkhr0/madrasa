import '../../auth/data/mock_users.dart';
import '../../auth/models/user_model.dart';
import '../../subjects/data/mock_subjects.dart';

/// The school's directory for the admin "People" tab.
class MockPeople {
  MockPeople._();

  static const _school = 'Al-Noor Preparatory School';

  static const _students = [
    ('Fatima Ali', '5th Scientific – A'),
    ('Maryam Hussein', '5th Scientific – A'),
    ('Noor Abbas', '5th Scientific – A'),
    ('Ali Hassan', '5th Scientific – B'),
    ('Mustafa Kareem', '5th Scientific – B'),
    ('Hussein Adel', '4th Scientific – A'),
    ('Yousif Raad', '4th Scientific – A'),
    ('Sara Mahdi', '6th Scientific – C'),
    ('Hawraa Kadhim', '6th Scientific – C'),
    ('Duaa Saad', '4th Scientific – A'),
    ('Ruqaya Salman', '4th Scientific – A'),
    ('Zahraa Jaafar', '5th Scientific – B'),
    ('Aya Ahmed', '5th Scientific – B'),
    // Not on a bus yet: the administrator can add them in Transport.
    ('Abbas Naji', '5th Scientific – A'),
    ('Rusul Hadi', '6th Scientific – C'),
    ('Tabarak Qasim', '4th Scientific – A'),
  ];

  /// Bus drivers. Kadhim drives bus 12 and Salam bus 7; Abbas is spare.
  static const _drivers = [
    ('DRV-2024-0019', 'Salam Hameed', '+964 780 222 7070'),
    ('DRV-2025-0027', 'Abbas Fadhil', '+964 771 640 3030'),
  ];

  static const _parents = [
    ('Ali Hassan Sr.', '+964 771 400 2211'),
    ('Kareem Mahmoud', '+964 780 300 9090'),
    ('Mahdi Saleh', '+964 750 111 7788'),
  ];

  static List<UserModel> get all {
    final users = <UserModel>[
      MockUsers.student,
      MockUsers.secondStudent,
      MockUsers.teacher,
      MockUsers.parent,
      MockUsers.driver,
    ];

    for (var i = 0; i < _students.length; i++) {
      final (name, className) = _students[i];
      users.add(
        UserModel(
          id: 'STU-2026-${(150 + i).toString().padLeft(4, '0')}',
          name: name,
          role: UserRole.student,
          email: '${name.toLowerCase().replaceAll(' ', '.')}@school.edu',
          phone: '',
          schoolName: _school,
          className: className,
          // One account not activated yet, so the screen shows that state.
          isActive: i != 4,
        ),
      );
    }

    // One teacher per subject (except maths, which is Mr. Ahmed).
    final otherSubjects = MockSubjects.all.where(
      (s) => s.id != MockSubjects.math.id,
    );
    var t = 40;
    for (final subject in otherSubjects) {
      users.add(
        UserModel(
          id: 'TCH-2019-${(t++).toString().padLeft(4, '0')}',
          name: subject.teacherName.replaceFirst(RegExp(r'^(Mr|Ms)\. '), ''),
          role: UserRole.teacher,
          email: 'teacher$t@school.edu',
          phone: '+964 780 555 0${100 + t}',
          schoolName: _school,
          subjectName: subject.name,
        ),
      );
    }

    for (var i = 0; i < _parents.length; i++) {
      final (name, phone) = _parents[i];
      users.add(
        UserModel(
          id: 'PAR-2026-${(150 + i).toString().padLeft(4, '0')}',
          name: name,
          role: UserRole.parent,
          email: '',
          phone: phone,
          schoolName: _school,
        ),
      );
    }

    for (final (id, name, phone) in _drivers) {
      users.add(
        UserModel(
          id: id,
          name: name,
          role: UserRole.driver,
          email: '',
          phone: phone,
          schoolName: _school,
        ),
      );
    }

    return users;
  }
}
