import '../../../core/network/api_client.dart';
import '../models/activity_item_model.dart';
import 'activity_repository.dart';

/// The activity log on the school API (server/src/features/activity).
class ApiActivityRepository implements ActivityRepository {
  final ApiClient _api;

  const ApiActivityRepository(this._api);

  @override
  Future<ActivityPageModel> list(
    ActivityFilter filter, {
    DateTime? before,
    int limit = 30,
  }) async {
    final query = Uri(
      queryParameters: {
        ...filter.toQuery(),
        if (before != null) 'before': before.toUtc().toIso8601String(),
        'limit': '$limit',
      },
    ).query;
    final json = await _api.get('/activity?$query') as Map<String, dynamic>;
    final next = json['next'] as String?;

    return ActivityPageModel(
      items: [
        for (final item in json['items'] as List)
          ActivityItemModel.fromJson(item as Map<String, dynamic>),
      ],
      next: next == null ? null : DateTime.parse(next),
    );
  }
}
