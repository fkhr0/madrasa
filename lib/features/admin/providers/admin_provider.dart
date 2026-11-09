import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/providers/clock_provider.dart';

import '../models/school_stats_model.dart';
import '../repo/admin_repository.dart';
import '../repo/api_admin_repository.dart';
import '../repo/mock_admin_repository.dart';

/// The server's numbers when API_URL is set, otherwise mock ones.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AppConfig.useApi
      ? ApiAdminRepository(watchApi(ref))
      : const MockAdminRepository(),
);

/// Reloads with the 15-second clock, so the office sees attendance come in.
final schoolStatsProvider = FutureProvider<SchoolStatsModel>((ref) {
  ref.watch(clockProvider);
  return ref.watch(adminRepositoryProvider).getTodayStats();
});
