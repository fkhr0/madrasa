import '../../../core/router/app_routes.dart';
import '../../auth/data/mock_users.dart';
import '../models/notification_model.dart';

class MockNotifications {
  MockNotifications._();

  static DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(
        Duration(days: days, hours: hours, minutes: minutes),
      );

  static List<NotificationModel> forUser(String userId) {
    if (userId == MockUsers.teacher.id) return _teacher;
    if (userId == MockUsers.parent.id) return _parent;
    if (userId == MockUsers.admin.id) return _admin;
    if (userId == MockUsers.student.id) return _student;

    // Drivers and new accounts start with none.
    return [];
  }

  static List<NotificationModel> get _teacher => [
    NotificationModel(
      id: 'tx1',
      type: NotificationType.assignment,
      title: '7 new submissions',
      body: 'Quadratic equations – worksheet 4 · 5th Scientific – A',
      createdAt: _ago(hours: 2),
      route: AppRoutes.classDetails('cls-5a'),
    ),
    NotificationModel(
      id: 'tx2',
      type: NotificationType.message,
      title: 'Haider Jasim sent a message',
      body: 'Thank you for the update, teacher.',
      createdAt: _ago(days: 1),
      route: AppRoutes.chat('t3'),
    ),
    NotificationModel(
      id: 'tx3',
      type: NotificationType.schedule,
      title: 'Department meeting',
      body: 'Mathematics department meeting in two days, staff room.',
      createdAt: _ago(days: 1, hours: 3),
      isRead: true,
      route: AppRoutes.calendar,
    ),
  ];

  static List<NotificationModel> get _admin => [
    NotificationModel(
      id: 'ax1',
      type: NotificationType.attendance,
      title: 'Attendance missing',
      body: '2 classes have not taken attendance for period 2.',
      createdAt: _ago(hours: 1),
      route: AppRoutes.home,
    ),
    NotificationModel(
      id: 'ax2',
      type: NotificationType.message,
      title: 'Mr. Ahmed Kareem sent a message',
      body: 'The department meeting room is booked.',
      createdAt: _ago(days: 1),
      route: AppRoutes.chat('a2'),
    ),
  ];

  static List<NotificationModel> get _parent => [
    NotificationModel(
      id: 'pbus1',
      type: NotificationType.transport,
      title: 'Zainab arrived at school',
      body: 'Bus 12 reached Al-Noor School at 07:45.',
      createdAt: _ago(hours: 1),
      isRead: true,
      route: AppRoutes.bus,
    ),
    NotificationModel(
      id: 'px1',
      type: NotificationType.attendance,
      title: 'Ali was absent yesterday',
      body: '2nd Intermediate – B · all periods',
      createdAt: _ago(hours: 20),
      route: AppRoutes.attendance,
    ),
    NotificationModel(
      id: 'px2',
      type: NotificationType.grade,
      title: 'New grade for Zainab',
      body: 'Arabic Language · Poetry analysis: 41 / 50',
      createdAt: _ago(days: 5),
      isRead: true,
      route: AppRoutes.grades,
    ),
    NotificationModel(
      id: 'px3',
      type: NotificationType.announcement,
      title: 'Parent–teacher meeting',
      body: 'Sunday, 2:00 – 5:00 pm in the main hall.',
      createdAt: _ago(days: 3),
      route: AppRoutes.calendar,
    ),
  ];

  static List<NotificationModel> get _student => [
    NotificationModel(
      id: 'bus1',
      type: NotificationType.transport,
      title: 'Bus 12 is 2 stops away',
      body: 'Expected at Al-Yarmouk at 07:22.',
      createdAt: _ago(minutes: 40),
      isRead: true,
      route: AppRoutes.bus,
    ),
    NotificationModel(
      id: 'x1',
      type: NotificationType.message,
      title: 'Mr. Ahmed Kareem replied',
      body: 'Yes, question 7 is optional this time.',
      createdAt: _ago(minutes: 12),
      route: AppRoutes.chat('c1'),
    ),
    NotificationModel(
      id: 'x2',
      type: NotificationType.announcement,
      title: 'Mid-term exams timetable published',
      body: 'Exams start on the 16th. Tap to read more.',
      createdAt: _ago(hours: 3),
      route: AppRoutes.announcementDetails('n1'),
    ),
    NotificationModel(
      id: 'x3',
      type: NotificationType.assignment,
      title: 'Due tomorrow',
      body: 'Quadratic equations – worksheet 4',
      createdAt: _ago(hours: 5),
      route: AppRoutes.assignmentDetails('a1'),
    ),
    NotificationModel(
      id: 'x4',
      type: NotificationType.schedule,
      title: 'Schedule change',
      body: 'Chemistry lab moved to Thursday.',
      createdAt: _ago(hours: 20),
      isRead: true,
    ),
    NotificationModel(
      id: 'x5',
      type: NotificationType.grade,
      title: 'New grade in Arabic Language',
      body: 'Poetry analysis: 41 / 50',
      createdAt: _ago(days: 5),
      isRead: true,
      route: AppRoutes.assignmentDetails('a7'),
    ),
    NotificationModel(
      id: 'x6',
      type: NotificationType.attendance,
      title: 'Marked late',
      body: 'You arrived at 08:20 on Monday.',
      createdAt: _ago(days: 2),
      isRead: true,
    ),
  ];
}
