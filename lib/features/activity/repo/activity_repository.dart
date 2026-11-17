import '../models/activity_item_model.dart';

abstract class ActivityRepository {
  Future<ActivityPageModel> list(
    ActivityFilter filter, {
    DateTime? before,
    int limit = 30,
  });
}
