import '../models/user_model.dart';

/// Fake accounts used until the backend is connected.
/// IDs follow the school's generator: STU- student, TCH- teacher,
/// PAR- parent, ADM- administrator, DRV- bus driver.
class MockUsers {
  MockUsers._();

  static const student = UserModel(
    id: 'STU-2026-0142',
    name: 'Zainab Haider',
    role: UserRole.student,
    email: 'zainab.haider@school.edu',
    phone: '+964 770 123 4567',
    schoolName: 'Al-Noor Preparatory School',
    className: '5th Scientific – A',
  );

  /// Zainab's younger brother (a second child for the parent account).
  static const secondStudent = UserModel(
    id: 'STU-2026-0388',
    name: 'Ali Haider',
    role: UserRole.student,
    email: 'ali.haider@school.edu',
    phone: '+964 770 123 4567',
    schoolName: 'Al-Noor Intermediate School',
    className: '2nd Intermediate – B',
  );

  static const teacher = UserModel(
    id: 'TCH-2019-0031',
    name: 'Ahmed Kareem',
    role: UserRole.teacher,
    email: 'ahmed.kareem@school.edu',
    phone: '+964 780 555 0131',
    schoolName: 'Al-Noor Preparatory School',
    subjectName: 'Mathematics',
  );

  static const parent = UserModel(
    id: 'PAR-2026-0142',
    name: 'Haider Jasim',
    role: UserRole.parent,
    email: 'haider.jasim@gmail.com',
    phone: '+964 770 123 4567',
    schoolName: 'Al-Noor Preparatory School',
    children: [student, secondStudent],
  );

  static const admin = UserModel(
    id: 'ADM-2020-0001',
    name: 'Salma Hashim',
    role: UserRole.admin,
    email: 'admin@alnoor.edu.iq',
    phone: '+964 790 222 1100',
    schoolName: 'Al-Noor Preparatory School',
  );

  static const driver = UserModel(
    id: 'DRV-2024-0012',
    name: 'Kadhim Jawad',
    role: UserRole.driver,
    email: '',
    phone: '+964 770 900 1212',
    schoolName: 'Al-Noor Preparatory School',
  );

  /// Shown on the login page in this demo build only.
  static const demoAccounts = [student, teacher, parent, admin, driver];
}
