import '../models/school_stats_model.dart';

abstract class AdminRepository {
  Future<SchoolStatsModel> getTodayStats();
}
