import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';

import '../models/insights_model.dart';
import '../repo/api_insights_repository.dart';
import '../repo/insights_repository.dart';
import '../repo/mock_insights_repository.dart';

final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => AppConfig.useApi
      ? ApiInsightsRepository(watchApi(ref))
      : const MockInsightsRepository(),
);

final insightsPeriodProvider = StateProvider<InsightsPeriod>(
  (ref) => InsightsPeriod.week,
);

final insightsProvider = FutureProvider<InsightsModel>(
  (ref) => ref
      .watch(insightsRepositoryProvider)
      .getInsights(ref.watch(insightsPeriodProvider)),
);
