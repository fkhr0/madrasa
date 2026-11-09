import '../models/school_stats_model.dart';

/// School-wide numbers for the administrator (who did what: features/activity).
/// MockAdminRepository or ApiAdminRepository.
abstract class AdminRepository {
  Future<SchoolStatsModel> getTodayStats();
}
