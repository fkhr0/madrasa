import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/l10n/arabic.dart';
import 'package:school/core/l10n/language.dart';
import 'package:school/core/providers/map_provider.dart';
import 'package:school/core/theme/app_palette.dart';
import 'package:school/features/activity/pages/activity_page.dart';
import 'package:school/features/days/pages/day_page.dart';
import 'package:school/features/resources/pages/class_resources_page.dart';
import 'package:school/features/finance/pages/fee_settings_page.dart';
import 'package:school/features/assignments/pages/assignment_editor_page.dart';
import 'package:school/features/assignments/pages/class_assignments_page.dart';
import 'package:school/features/exams/pages/class_exams_page.dart';
import 'package:school/features/exams/pages/exam_scores_page.dart';
import 'package:school/features/timetable/pages/bell_times_page.dart';
import 'package:school/features/timetable/pages/class_timetable_page.dart';
import 'package:school/features/academics/pages/academics_page.dart';
import 'package:school/features/academics/pages/school_class_page.dart';
import 'package:school/features/admin/pages/admin_home_page.dart';
import 'package:school/features/announcements/pages/announcements_page.dart';
import 'package:school/features/announcements/pages/new_announcement_page.dart';
import 'package:school/features/assignments/pages/assignment_details_page.dart';
import 'package:school/features/assignments/pages/assignments_page.dart';
import 'package:school/features/attendance/pages/attendance_page.dart';
import 'package:school/features/auth/data/mock_users.dart';
import 'package:school/features/auth/models/user_model.dart';
import 'package:school/features/auth/pages/login_page.dart';
import 'package:school/features/auth/providers/auth_provider.dart';
import 'package:school/features/calendar/pages/calendar_page.dart';
import 'package:school/features/dashboard/pages/dashboard_page.dart';
import 'package:school/features/driver/pages/driver_home_page.dart';
import 'package:school/features/finance/pages/fees_page.dart';
import 'package:school/features/finance/pages/finance_page.dart';
import 'package:school/features/finance/pages/student_account_page.dart';
import 'package:school/features/insights/pages/statistics_page.dart';
import 'package:school/features/transport/pages/route_edit_page.dart';
import 'package:school/features/transport/pages/route_stops_page.dart';
import 'package:school/features/transport/pages/route_students_page.dart';
import 'package:school/features/transport/pages/transport_settings_page.dart';
import 'package:school/features/exams/pages/exams_page.dart';
import 'package:school/features/grades/pages/grades_page.dart';
import 'package:school/features/help/pages/help_page.dart';
import 'package:school/features/institution/pages/school_settings_page.dart';
import 'package:school/features/messages/pages/chat_page.dart';
import 'package:school/features/messages/pages/conversations_page.dart';
import 'package:school/features/more/pages/more_page.dart';
import 'package:school/features/notifications/pages/notifications_page.dart';
import 'package:school/features/parent/pages/parent_home_page.dart';
import 'package:school/features/parent/pages/progress_page.dart';
import 'package:school/features/people/pages/add_person_page.dart';
import 'package:school/features/people/pages/people_page.dart';
import 'package:school/features/people/pages/person_details_page.dart';
import 'package:school/features/planner/pages/planner_page.dart';
import 'package:school/features/profile/pages/change_password_page.dart';
import 'package:school/features/profile/pages/edit_profile_page.dart';
import 'package:school/features/profile/pages/profile_page.dart';
import 'package:school/features/resources/pages/resources_page.dart';
import 'package:school/features/schedule/pages/schedule_page.dart';
import 'package:school/features/settings/pages/settings_page.dart';
import 'package:school/features/tasks/pages/tasks_page.dart';
import 'package:school/features/teaching/pages/class_details_page.dart';
import 'package:school/features/teaching/pages/classes_page.dart';
import 'package:school/features/teaching/pages/take_attendance_page.dart';
import 'package:school/features/teaching/pages/teacher_home_page.dart';
import 'package:school/features/transport/models/trip_model.dart';
import 'package:school/features/transport/pages/bus_page.dart';
import 'package:school/features/transport/pages/route_details_page.dart';
import 'package:school/features/transport/providers/transport_provider.dart';
import 'package:school/features/transport/pages/transport_admin_page.dart';

/// Renders every page on a small phone screen in light and dark mode, and in
/// Arabic (right to left).
void main() {
  final studentPages = <String, Widget>{
    'login': const LoginPage(),
    'dashboard': const DashboardPage(),
    'schedule': const SchedulePage(),
    'assignments': const AssignmentsPage(),
    'assignment pending': const AssignmentDetailsPage(assignmentId: 'a2'),
    'assignment graded': const AssignmentDetailsPage(assignmentId: 'a6'),
    'messages': const ConversationsPage(),
    'chat': const ChatPage(conversationId: 'c1'),
    'grades': const GradesPage(),
    'attendance': const AttendancePage(),
    'student attendance (admin)': const AttendancePage(
      studentId: 'STU-2026-0142',
    ),
    'announcements': const AnnouncementsPage(),
    'notifications': const NotificationsPage(),
    'more': const MorePage(),
    'profile': const ProfilePage(),
    'settings': const SettingsPage(),
    'calendar': const CalendarPage(),
    'exams': const ExamsPage(),
    'resources': const ResourcesPage(),
    'tasks': const TasksPage(),
    'help': const HelpPage(),
    'edit profile': const EditProfilePage(),
    'change password': const ChangePasswordPage(),
    'planner': const PlannerPage(),
    'bus': const BusPage(),
  };

  final teacherPages = <String, Widget>{
    'teacher home': const TeacherHomePage(),
    'teacher schedule': const SchedulePage(),
    'classes': const ClassesPage(),
    'class details': const ClassDetailsPage(classId: 'cls-5a'),
    'take attendance': const TakeAttendancePage(classId: 'cls-5a'),
    'new assignment': const AssignmentEditorPage(classId: 'cls-5a'),
    'class homework': const ClassAssignmentsPage(classId: 'cls-5a'),
    'class material': const ClassResourcesPage(classId: 'cls-5a'),
    'class exams': const ClassExamsPage(classId: 'cls-5a'),
    'exam scores': const ExamScoresPage(examId: 'e1-cls-5a'),
    'teacher calendar': const CalendarPage(),
    'teacher messages': const ConversationsPage(),
    'teacher more': const MorePage(),
    'teacher profile': const ProfilePage(),
    'new announcement (teacher)': const NewAnnouncementPage(),
    'teacher planner': const PlannerPage(),
  };

  final parentPages = <String, Widget>{
    'parent home': const ParentHomePage(),
    'parent progress': const ProgressPage(),
    'parent schedule': const SchedulePage(),
    'parent assignment': const AssignmentDetailsPage(assignmentId: 'a1'),
    'parent calendar': const CalendarPage(),
    'parent notifications': const NotificationsPage(),
    'parent more': const MorePage(),
    'parent profile': const ProfilePage(),
    'parent planner': const PlannerPage(),
    'parent bus': const BusPage(),
    'parent fees': const FeesPage(),
  };

  final adminPages = <String, Widget>{
    'admin home': const AdminHomePage(),
    'academics': const AcademicsPage(),
    'school class': const SchoolClassPage(classId: 'cls-5b'),
    'class timetable': const ClassTimetablePage(classId: 'cls-5a'),
    'bell times': const BellTimesPage(),
    'people': const PeoplePage(),
    'person details': const PersonDetailsPage(personId: 'STU-2026-0142'),
    'add person': const AddPersonPage(),
    'school settings': const SchoolSettingsPage(),
    'admin announcements': const AnnouncementsPage(),
    'new announcement (admin)': const NewAnnouncementPage(),
    'edit announcement': const NewAnnouncementPage(announcementId: 'n1'),
    'edit person': const AddPersonPage(personId: 'STU-2026-0142'),
    'admin calendar': const CalendarPage(),
    'admin more': const MorePage(),
    'transport': const TransportAdminPage(),
    'transport settings': const TransportSettingsPage(),
    'route details (admin)': const RouteDetailsPage(routeId: 'route-1'),
    'edit route': const RouteEditPage(routeId: 'route-1'),
    'new route': const RouteEditPage(),
    'route stops': const RouteStopsPage(routeId: 'route-1'),
    'route riders': const RouteStudentsPage(routeId: 'route-1'),
    'driver account': const PersonDetailsPage(personId: 'DRV-2024-0012'),
    'statistics': const StatisticsPage(),
    'finance': const FinancePage(),
    'fee settings': const FeeSettingsPage(),
    'day': const DayPage(),
    'activity': const ActivityPage(),
    'student account': const StudentAccountPage(studentId: 'STU-2026-0388'),
  };

  final driverPages = <String, Widget>{
    'driver home': const DriverHomePage(),
    'driver home (live trip)': const DriverHomePage(),
    'driver route': const RouteDetailsPage(),
    'driver more': const MorePage(),
  };

  /// Pages tested while the driver is running a trip.
  const liveTripPages = {'driver home (live trip)', 'bus (live trip)'};
  studentPages['bus (live trip)'] = const BusPage();

  final accounts = <UserModel, Map<String, Widget>>{
    MockUsers.student: studentPages,
    MockUsers.teacher: teacherPages,
    MockUsers.parent: parentPages,
    MockUsers.admin: adminPages,
    MockUsers.driver: driverPages,
  };

  // Light and dark in English, and light in Arabic (right to left).
  const modes = [
    (Brightness.light, AppLanguage.en),
    (Brightness.dark, AppLanguage.en),
    (Brightness.light, AppLanguage.ar),
  ];

  for (final (brightness, language) in modes) {
    final mode = language == AppLanguage.ar ? 'arabic' : brightness.name;
    for (final MapEntry(key: account, value: pages) in accounts.entries) {
      for (final entry in pages.entries) {
        testWidgets('${entry.key} ($mode)', (tester) async {
          tester.view.physicalSize = const Size(360, 720);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          AppLanguage.current = language;
          addTearDown(() => AppLanguage.current = AppLanguage.en);

          // No internet in tests: maps draw without OpenStreetMap tiles.
          final container = ProviderContainer(
            overrides: [mapTilesEnabledProvider.overrideWithValue(false)],
          );
          // Pages behind the login need a signed-in user. runAsync uses real
          // time, because the mock sign-in waits with Future.delayed.
          await tester.runAsync(
            () => container
                .read(authProvider.notifier)
                .signIn(schoolId: account.id, password: '1234'),
          );
          if (liveTripPages.contains(entry.key)) {
            await tester.runAsync(
              () => container
                  .read(transportActionsProvider)
                  .startTrip('route-1', TripDirection.toSchool),
            );
          }

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: language.locale,
                supportedLocales: [
                  for (final l in AppLanguage.values) l.locale,
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: ThemeData(
                  brightness: brightness,
                  extensions: [
                    brightness == Brightness.light
                        ? AppPalette.light
                        : AppPalette.dark,
                  ],
                ),
                home: entry.value,
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);

          // In Arabic, no English sentence from the dictionary may show: it
          // would mean a text that skipped tr().
          if (language == AppLanguage.ar) {
            final english = {
              for (final MapEntry(:key, :value) in arabic.entries)
                if (key != value) key,
            };
            final shown = [
              for (final text in tester.widgetList<Text>(find.byType(Text)))
                ?text.data,
            ];
            expect(shown.where(english.contains), isEmpty);
          }

          // Dispose inside the test so the clock and bus timers stop
          // before Flutter checks for pending timers.
          await tester.pumpWidget(const SizedBox());
          container.dispose();
        });
      }
    }
  }
}
