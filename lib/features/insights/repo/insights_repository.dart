import '../models/insights_model.dart';

/// School statistics for administrators.
/// MockInsightsRepository or ApiInsightsRepository (worked out on request;
/// a nightly job can cache them when schools get big).
abstract class InsightsRepository {
  Future<InsightsModel> getInsights(InsightsPeriod period);
}
