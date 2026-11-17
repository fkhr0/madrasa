import '../../../core/network/api_client.dart';
import '../models/insights_model.dart';
import 'insights_repository.dart';

class ApiInsightsRepository implements InsightsRepository {
  final ApiClient _api;

  const ApiInsightsRepository(this._api);

  @override
  Future<InsightsModel> getInsights(InsightsPeriod period) async =>
      InsightsModel.fromJson(
        await _api.get('/reports/insights?period=${period.name}')
            as Map<String, dynamic>,
      );
}
