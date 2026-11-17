import '../../../core/network/api_client.dart';
import '../models/school_stats_model.dart';
import 'admin_repository.dart';

class ApiAdminRepository implements AdminRepository {
  final ApiClient _api;

  const ApiAdminRepository(this._api);

  @override
  Future<SchoolStatsModel> getTodayStats() async => SchoolStatsModel.fromJson(
    await _api.get('/reports/today') as Map<String, dynamic>,
  );
}
