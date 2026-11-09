import '../models/announcement_model.dart';

class MockAnnouncements {
  MockAnnouncements._();

  static DateTime _ago({int days = 0, int hours = 0}) =>
      DateTime.now().subtract(Duration(days: days, hours: hours));

  static List<AnnouncementModel> get items => [
    AnnouncementModel(
      id: 'n1',
      title: 'Mid-term exams timetable published',
      body:
          'The mid-term exam timetable is now available in the Exams section. '
          'Exams start on the 16th and run for two weeks. Please arrive 15 '
          'minutes early and bring your student card.\n\n'
          'If you have two exams on the same day, contact the exams office.',
      authorName: 'Exams Office',
      audience: AnnouncementAudience.school,
      publishedAt: _ago(hours: 3),
      isPinned: true,
    ),
    AnnouncementModel(
      id: 'n2',
      title: 'Chemistry lab moved to Thursday',
      body:
          'This week\'s chemistry lab session is moved from Wednesday to '
          'Thursday, same time. Lab coats are required.',
      authorName: 'Mr. Omar Saleh',
      audience: AnnouncementAudience.className,
      className: '5th Scientific – A',
      publishedAt: _ago(hours: 20),
    ),
    AnnouncementModel(
      id: 'n3',
      title: 'Parent–teacher meeting',
      body:
          'Parents are invited to meet teachers next Monday from 2:00 pm to '
          '5:00 pm in the main hall. Booking a time slot is not required.',
      authorName: 'School Administration',
      audience: AnnouncementAudience.parents,
      publishedAt: _ago(days: 2),
    ),
    AnnouncementModel(
      id: 'n4',
      title: 'Library opening hours extended',
      body:
          'During the exam period the library will stay open until 6:00 pm '
          'from Sunday to Thursday.',
      authorName: 'Library',
      audience: AnnouncementAudience.school,
      publishedAt: _ago(days: 4),
    ),
    AnnouncementModel(
      id: 'n5',
      title: 'Class photo day',
      body:
          'Class photos will be taken on Tuesday morning. Please wear the full '
          'school uniform.',
      authorName: 'Ms. Huda Jaber',
      audience: AnnouncementAudience.className,
      className: '5th Scientific – A',
      publishedAt: _ago(days: 6),
    ),
  ];
}
