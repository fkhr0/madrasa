import '../../../core/network/api_client.dart';
import '../models/announcement_model.dart';
import 'announcement_repository.dart';

class ApiAnnouncementRepository implements AnnouncementRepository {
  final ApiClient _api;

  const ApiAnnouncementRepository(this._api);

  @override
  Future<List<AnnouncementModel>> getAll() async {
    final list = await _api.get('/announcements') as List;
    return [
      for (final json in list)
        AnnouncementModel.fromJson(json as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> publish(AnnouncementModel announcement) =>
      _api.post('/announcements', announcement.toJson());

  @override
  Future<void> update(AnnouncementModel announcement) =>
      _api.patch('/announcements/${announcement.id}', announcement.toJson());

  @override
  Future<void> delete(String id) => _api.delete('/announcements/$id');
}
