import '../models/insights_model.dart';

/// School statistics for administrators.
abstract class InsightsRepository {
  Future<InsightsModel> getInsights(InsightsPeriod period);
}
