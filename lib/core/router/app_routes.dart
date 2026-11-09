import '../utils/day_json.dart';

/// Every path in the app. Use these instead of typing strings,
/// e.g. `context.push(AppRoutes.assignmentDetails(id))`.
class AppRoutes {
  AppRoutes._();

  // Signed out
  static const login = '/login';
  static const forgotPassword = '/forgot-password';

  // Bottom navigation tabs. The third tab changes with the role:
  // Assignments (student), Classes (teacher), Progress (parent).
  static const home = '/home';
  static const schedule = '/schedule';
  static const work = '/work';
  static const messages = '/messages';
  static const more = '/more';

  // Full-screen pages
  static const assignments = '/assignments';
  static String assignmentDetails(String id) => '$assignments/$id';

  static const newAnnouncement = '/announcements/new';

  // Administrator
  static const people = '/people';
  static const addPerson = '/people/new';
  static String personDetails(String id) => '$people/$id';
  static String editPerson(String id) => '$people/$id/edit';
  static String personAttendance(String id) => '$people/$id/attendance';
  static String schoolClass(String id) => '/academics/classes/$id';
  static String classTimetable(String id) => '/academics/classes/$id/timetable';
  static const bellTimes = '/academics/bell-times';
  static const schoolSettings = '/school-settings';

  // Teacher
  static const classes = '/classes';
  static String classDetails(String id) => '$classes/$id';
  static String takeAttendance(String id) => '$classes/$id/attendance';
  static String newAssignment(String id) => '$classes/$id/assignment';
  static String editAssignment(String classId, String id) =>
      '$classes/$classId/assignment/$id';

  /// A class's homework (teacher or office).
  static String classAssignments(String id) => '$classes/$id/homework';

  /// A class's study material (teacher or office).
  static String classResources(String id) => '$classes/$id/material';
  static String submissions(String assignmentId) =>
      '$assignments/$assignmentId/submissions';

  /// A class's exams and their scores (teacher or office).
  static String classExams(String id) => '$classes/$id/exams';
  static String examScores(String examId) => '/exams/$examId/scores';
  static String chat(String conversationId) => '$messages/$conversationId';

  /// True for the bottom tabs and the pages inside them (e.g. a chat).
  /// Those are opened with `go` (switch tab); pushing them on top of a
  /// full-screen page would put a second copy of the tabs on the stack.
  static bool isInTabs(String location) {
    const tabs = [home, schedule, work, messages, more];
    return tabs.any((tab) => location == tab || location.startsWith('$tab/'));
  }

  /// A day at school for the signed-in person (office: the whole school).
  static const day = '/day';
  static String dayOn(DateTime date) => '$day?date=${formatDay(date)}';

  /// Who did what, with filters.
  static const activity = '/activity';
  static String activityOn(DateTime date) =>
      '$activity?date=${formatDay(date)}';

  static const announcements = '/announcements';
  static String announcementDetails(String id) => '$announcements/$id';
  static String editAnnouncement(String id) => '$announcements/$id/edit';

  static const grades = '/grades';
  static const attendance = '/attendance';
  static const notifications = '/notifications';
  static const calendar = '/calendar';
  static const exams = '/exams';
  static const resources = '/resources';
  static const tasks = '/tasks';
  static const help = '/help';
  static const planner = '/planner';
  static const bus = '/bus';
  static const transport = '/transport';
  static String busRoute(String id) => '$transport/$id';
  static const newRoute = '$transport/new';
  static const transportSettings = '$transport/settings';
  static String editRoute(String id) => '$transport/$id/edit';
  static String routeStops(String id) => '$transport/$id/stops';
  static String routeStudents(String id) => '$transport/$id/students';

  // Administrator: numbers and money
  static const statistics = '/statistics';
  static const finance = '/finance';
  static const feeSettings = '/fee-settings';
  static String studentAccount(String studentId) => '$finance/$studentId';

  // Parent: the active child's fees
  static const fees = '/fees';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';
  static const settings = '/settings';
}
