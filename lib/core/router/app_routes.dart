import '../utils/day_json.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const forgotPassword = '/forgot-password';

  static const home = '/home';
  static const schedule = '/schedule';
  static const work = '/work';
  static const messages = '/messages';
  static const more = '/more';

  static const assignments = '/assignments';
  static String assignmentDetails(String id) => '$assignments/$id';

  static const newAnnouncement = '/announcements/new';

  static const people = '/people';
  static const addPerson = '/people/new';
  static String personDetails(String id) => '$people/$id';
  static String editPerson(String id) => '$people/$id/edit';
  static String personAttendance(String id) => '$people/$id/attendance';
  static String schoolClass(String id) => '/academics/classes/$id';
  static String classTimetable(String id) => '/academics/classes/$id/timetable';
  static const bellTimes = '/academics/bell-times';
  static const schoolSettings = '/school-settings';

  static const classes = '/classes';
  static String classDetails(String id) => '$classes/$id';
  static String takeAttendance(String id) => '$classes/$id/attendance';
  static String newAssignment(String id) => '$classes/$id/assignment';
  static String editAssignment(String classId, String id) =>
      '$classes/$classId/assignment/$id';

  static String classAssignments(String id) => '$classes/$id/homework';

  static String classResources(String id) => '$classes/$id/material';
  static String submissions(String assignmentId) =>
      '$assignments/$assignmentId/submissions';

  static String classExams(String id) => '$classes/$id/exams';
  static String examScores(String examId) => '/exams/$examId/scores';
  static String chat(String conversationId) => '$messages/$conversationId';

  static bool isInTabs(String location) {
    const tabs = [home, schedule, work, messages, more];
    return tabs.any((tab) => location == tab || location.startsWith('$tab/'));
  }

  static const day = '/day';
  static String dayOn(DateTime date) => '$day?date=${formatDay(date)}';

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

  static const statistics = '/statistics';
  static const finance = '/finance';
  static const feeSettings = '/fee-settings';
  static String studentAccount(String studentId) => '$finance/$studentId';

  static const fees = '/fees';

  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const changePassword = '/profile/password';
  static const settings = '/settings';
}
