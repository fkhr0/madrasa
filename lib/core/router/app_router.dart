import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academics/pages/academics_page.dart';
import '../../features/activity/pages/activity_page.dart';
import '../../features/days/pages/day_page.dart';
import '../../features/academics/pages/school_class_page.dart';
import '../../features/admin/pages/admin_home_page.dart';
import '../../features/announcements/pages/announcement_details_page.dart';
import '../../features/announcements/pages/announcements_page.dart';
import '../../features/announcements/pages/new_announcement_page.dart';
import '../../features/assignments/pages/assignment_details_page.dart';
import '../../features/assignments/pages/assignment_editor_page.dart';
import '../../features/assignments/pages/assignments_page.dart';
import '../../features/assignments/pages/class_assignments_page.dart';
import '../../features/assignments/pages/submissions_page.dart';
import '../../features/attendance/pages/attendance_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/calendar/pages/calendar_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/driver/pages/driver_home_page.dart';
import '../../features/exams/pages/class_exams_page.dart';
import '../../features/exams/pages/exam_scores_page.dart';
import '../../features/exams/pages/exams_page.dart';
import '../../features/finance/pages/finance_page.dart';
import '../../features/finance/pages/fee_settings_page.dart';
import '../../features/finance/pages/fees_page.dart';
import '../../features/finance/pages/student_account_page.dart';
import '../../features/grades/pages/grades_page.dart';
import '../../features/help/pages/help_page.dart';
import '../../features/insights/pages/statistics_page.dart';
import '../../features/institution/pages/school_settings_page.dart';
import '../../features/messages/pages/chat_page.dart';
import '../../features/messages/pages/conversations_page.dart';
import '../../features/more/pages/more_page.dart';
import '../../features/navigation/pages/main_shell.dart';
import '../../features/navigation/widgets/role_switch.dart';
import '../../features/notifications/pages/notifications_page.dart';
import '../../features/parent/pages/parent_home_page.dart';
import '../../features/parent/pages/progress_page.dart';
import '../../features/people/pages/add_person_page.dart';
import '../../features/people/pages/people_page.dart';
import '../../features/people/pages/person_details_page.dart';
import '../../features/planner/pages/planner_page.dart';
import '../../features/profile/pages/change_password_page.dart';
import '../../features/profile/pages/edit_profile_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/resources/pages/class_resources_page.dart';
import '../../features/resources/pages/resources_page.dart';
import '../../features/schedule/pages/schedule_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/timetable/pages/bell_times_page.dart';
import '../../features/timetable/pages/class_timetable_page.dart';
import '../../features/tasks/pages/tasks_page.dart';
import '../../features/teaching/pages/class_details_page.dart';
import '../../features/teaching/pages/classes_page.dart';
import '../../features/teaching/pages/take_attendance_page.dart';
import '../../features/teaching/pages/teacher_home_page.dart';
import '../../features/transport/pages/bus_page.dart';
import '../../features/transport/pages/route_details_page.dart';
import '../../features/transport/pages/route_edit_page.dart';
import '../../features/transport/pages/route_stops_page.dart';
import '../../features/transport/pages/route_students_page.dart';
import '../../features/transport/pages/transport_admin_page.dart';
import '../../features/transport/pages/transport_settings_page.dart';
import 'app_routes.dart';

/// Pages pushed on this navigator cover the bottom bar.
final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// "?date=2026-11-08" in the address, or null.
DateTime? _dateParam(GoRouterState state) =>
    DateTime.tryParse(state.uri.queryParameters['date'] ?? '');

/// Shortcut for a simple full-screen route.
GoRoute _page(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(path: path, builder: (context, state) => build(state));

final routerProvider = Provider<GoRouter>((ref) {
  // Tells GoRouter to re-check `redirect` whenever the user signs in or out.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: authChanges,

    redirect: (context, state) {
      final signedIn = ref.read(authProvider) != null;
      final onAuthPage =
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.forgotPassword;

      if (!signedIn && !onAuthPage) return AppRoutes.login;
      if (signedIn && onAuthPage) return AppRoutes.home;

      // A temporary password from the school: choose your own first.
      final mustChange = ref.read(authProvider)?.mustChangePassword ?? false;
      if (mustChange && state.matchedLocation != AppRoutes.changePassword) {
        return AppRoutes.changePassword;
      }

      return null;
    },

    routes: [
      // ---------- Signed out ----------
      _page(AppRoutes.login, (_) => const LoginPage()),
      _page(AppRoutes.forgotPassword, (_) => const ForgotPasswordPage()),

      // ---------- Tabs with the bottom bar (content depends on role) ----------
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              _page(
                AppRoutes.home,
                (_) => const RoleSwitch(
                  student: DashboardPage(),
                  teacher: TeacherHomePage(),
                  parent: ParentHomePage(),
                  admin: AdminHomePage(),
                  driver: DriverHomePage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _page(
                AppRoutes.schedule,
                (_) => const RoleSwitch(
                  student: SchedulePage(),
                  teacher: SchedulePage(),
                  parent: SchedulePage(),
                  admin: AcademicsPage(),
                  driver: RouteDetailsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              _page(
                AppRoutes.work,
                (_) => const RoleSwitch(
                  student: AssignmentsPage(),
                  teacher: ClassesPage(),
                  parent: ProgressPage(),
                  admin: PeoplePage(),
                  // Drivers have no third tab; links here show their line.
                  driver: RouteDetailsPage(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                builder: (context, state) => const ConversationsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) =>
                        ChatPage(conversationId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [_page(AppRoutes.more, (_) => const MorePage())],
          ),
        ],
      ),

      // ---------- Full-screen pages ----------
      _page(
        '${AppRoutes.assignments}/:id',
        (s) => AssignmentDetailsPage(assignmentId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        builder: (context, state) => const AnnouncementsPage(),
        routes: [
          // "new" must come before ":id", or it would be read as an ID.
          GoRoute(
            path: 'new',
            builder: (context, state) => const NewAnnouncementPage(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => AnnouncementDetailsPage(
              announcementId: state.pathParameters['id']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => NewAnnouncementPage(
                  announcementId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
      _page(AppRoutes.grades, (_) => const GradesPage()),
      _page(AppRoutes.attendance, (_) => const AttendancePage()),
      _page(AppRoutes.notifications, (_) => const NotificationsPage()),
      _page(AppRoutes.calendar, (_) => const CalendarPage()),
      _page(AppRoutes.exams, (_) => const ExamsPage()),
      _page(AppRoutes.resources, (_) => const ResourcesPage()),
      _page(AppRoutes.tasks, (_) => const TasksPage()),
      _page(AppRoutes.help, (_) => const HelpPage()),
      _page(AppRoutes.planner, (_) => const PlannerPage()),
      _page(AppRoutes.bus, (_) => const BusPage()),
      GoRoute(
        path: AppRoutes.transport,
        builder: (context, state) => const TransportAdminPage(),
        routes: [
          // Fixed words before ":id", or they would be read as an ID.
          GoRoute(
            path: 'new',
            builder: (context, state) => const RouteEditPage(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const TransportSettingsPage(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                RouteDetailsPage(routeId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    RouteEditPage(routeId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'stops',
                builder: (context, state) =>
                    RouteStopsPage(routeId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'students',
                builder: (context, state) =>
                    RouteStudentsPage(routeId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      _page(AppRoutes.statistics, (_) => const StatisticsPage()),
      _page(AppRoutes.finance, (_) => const FinancePage()),
      _page(AppRoutes.feeSettings, (_) => const FeeSettingsPage()),
      _page(AppRoutes.day, (s) => DayPage(date: _dateParam(s))),
      _page(AppRoutes.activity, (s) => ActivityPage(date: _dateParam(s))),
      _page(
        '${AppRoutes.finance}/:id',
        (s) => StudentAccountPage(studentId: s.pathParameters['id']!),
      ),
      _page(AppRoutes.fees, (_) => const FeesPage()),
      _page(AppRoutes.profile, (_) => const ProfilePage()),
      _page(AppRoutes.editProfile, (_) => const EditProfilePage()),
      _page(AppRoutes.changePassword, (_) => const ChangePasswordPage()),
      _page(AppRoutes.settings, (_) => const SettingsPage()),

      // ---------- Administrator ----------
      _page(AppRoutes.addPerson, (_) => const AddPersonPage()),
      _page(
        '${AppRoutes.people}/:id',
        (s) => PersonDetailsPage(personId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.people}/:id/edit',
        (s) => AddPersonPage(personId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.people}/:id/attendance',
        (s) => AttendancePage(studentId: s.pathParameters['id']!),
      ),
      _page(
        '/academics/classes/:id',
        (s) => SchoolClassPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '/academics/classes/:id/timetable',
        (s) => ClassTimetablePage(classId: s.pathParameters['id']!),
      ),
      _page(AppRoutes.bellTimes, (_) => const BellTimesPage()),
      _page(AppRoutes.schoolSettings, (_) => const SchoolSettingsPage()),

      // ---------- Teacher ----------
      _page(
        '${AppRoutes.classes}/:id',
        (s) => ClassDetailsPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.classes}/:id/attendance',
        (s) => TakeAttendancePage(classId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.classes}/:id/assignment',
        (s) => AssignmentEditorPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.classes}/:id/assignment/:assignmentId',
        (s) => AssignmentEditorPage(
          classId: s.pathParameters['id']!,
          assignmentId: s.pathParameters['assignmentId'],
        ),
      ),
      _page(
        '${AppRoutes.classes}/:id/material',
        (s) => ClassResourcesPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.classes}/:id/homework',
        (s) => ClassAssignmentsPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.assignments}/:id/submissions',
        (s) => SubmissionsPage(assignmentId: s.pathParameters['id']!),
      ),
      _page(
        '${AppRoutes.classes}/:id/exams',
        (s) => ClassExamsPage(classId: s.pathParameters['id']!),
      ),
      _page(
        '/exams/:id/scores',
        (s) => ExamScoresPage(examId: s.pathParameters['id']!),
      ),
    ],
  );
});
