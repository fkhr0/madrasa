import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/activity_item_model.dart';
import '../repo/activity_repository.dart';
import '../repo/api_activity_repository.dart';
import '../repo/mock_activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => AppConfig.useApi
      ? ApiActivityRepository(watchApi(ref))
      : const MockActivityRepository(),
);

final recentActivityProvider = FutureProvider<List<ActivityItemModel>>((
  ref,
) async {
  ref.watch(authProvider.select((user) => user?.id));
  final page = await ref
      .watch(activityRepositoryProvider)
      .list(const ActivityFilter(), limit: 6);
  return page.items;
});

final activityFeedProvider =
    AsyncNotifierProvider.family<
      ActivityFeed,
      ActivityFeedState,
      ActivityFilter
    >(ActivityFeed.new);

class ActivityFeedState {
  final List<ActivityItemModel> items;

  final DateTime? next;
  final bool loadingMore;

  const ActivityFeedState({
    required this.items,
    this.next,
    this.loadingMore = false,
  });
}

class ActivityFeed
    extends FamilyAsyncNotifier<ActivityFeedState, ActivityFilter> {
  @override
  Future<ActivityFeedState> build(ActivityFilter filter) async {
    ref.watch(authProvider.select((user) => user?.id));
    final page = await ref.watch(activityRepositoryProvider).list(filter);
    return ActivityFeedState(items: page.items, next: page.next);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.next == null || current.loadingMore) return;
    state = AsyncData(
      ActivityFeedState(
        items: current.items,
        next: current.next,
        loadingMore: true,
      ),
    );
    try {
      final page = await ref
          .read(activityRepositoryProvider)
          .list(arg, before: current.next);
      state = AsyncData(
        ActivityFeedState(
          items: [...current.items, ...page.items],
          next: page.next,
        ),
      );
    } catch (_) {
      state = AsyncData(
        ActivityFeedState(items: current.items, next: current.next),
      );
    }
  }
}
