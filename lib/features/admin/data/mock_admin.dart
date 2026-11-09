import '../models/school_stats_model.dart';

class MockAdmin {
  MockAdmin._();

  static const stats = SchoolStatsModel(
    students: 124,
    teachers: 24,
    parents: 118,
    classes: 4,
    presentToday: 117,
    absentToday: 7,
    classesMissingAttendance: ['4th Scientific – A', '6th Scientific – C'],
  );
}
