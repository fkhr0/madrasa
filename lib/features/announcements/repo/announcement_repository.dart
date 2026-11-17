import '../models/announcement_model.dart';

abstract class AnnouncementRepository {
  Future<List<AnnouncementModel>> getAll();

  Future<void> publish(AnnouncementModel announcement);

  Future<void> update(AnnouncementModel announcement);

  Future<void> delete(String id);
}
