import '../data/mock_admin.dart';
import '../models/school_stats_model.dart';
import 'admin_repository.dart';

class MockAdminRepository implements AdminRepository {
  const MockAdminRepository();

  @override
  Future<SchoolStatsModel> getTodayStats() async => MockAdmin.stats;
}
