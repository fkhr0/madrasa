import '../data/mock_insights.dart';
import '../models/insights_model.dart';
import 'insights_repository.dart';

class MockInsightsRepository implements InsightsRepository {
  const MockInsightsRepository();

  @override
  Future<InsightsModel> getInsights(InsightsPeriod period) async =>
      MockInsights.forPeriod(period);
}
