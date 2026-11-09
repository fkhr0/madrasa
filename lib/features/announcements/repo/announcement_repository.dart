import '../models/announcement_model.dart';

/// MockAnnouncementRepository (no server) or ApiAnnouncementRepository.
abstract class AnnouncementRepository {
  /// Published announcements, pinned first, then newest first.
  Future<List<AnnouncementModel>> getAll();

  /// Teachers (their classes) and administrators only.
  /// A future [AnnouncementModel.publishedAt] schedules it.
  Future<void> publish(AnnouncementModel announcement);

  /// Replaces the announcement with the same ID (edit, pin, unpin).
  Future<void> update(AnnouncementModel announcement);

  Future<void> delete(String id);
}
