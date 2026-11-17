import '../models/insights_model.dart';

abstract class InsightsRepository {
  Future<InsightsModel> getInsights(InsightsPeriod period);
}
