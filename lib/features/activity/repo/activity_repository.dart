import '../models/activity_item_model.dart';

/// Who did what, and when. MockActivityRepository or ApiActivityRepository.
/// Each role gets only its part (the server decides).
abstract class ActivityRepository {
  /// Newest first; [before] continues an earlier page.
  Future<ActivityPageModel> list(
    ActivityFilter filter, {
    DateTime? before,
    int limit = 30,
  });
}
