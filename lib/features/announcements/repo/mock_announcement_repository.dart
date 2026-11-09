import '../data/mock_announcements.dart';
import '../models/announcement_model.dart';
import 'announcement_repository.dart';

/// Keeps announcements in memory so publishing works during the session.
class MockAnnouncementRepository implements AnnouncementRepository {
  final List<AnnouncementModel> _items = MockAnnouncements.items;

  @override
  Future<List<AnnouncementModel>> getAll() async {
    final now = DateTime.now();

    // Scheduled ones stay hidden until their time comes.
    return _items.where((a) => !a.publishedAt.isAfter(now)).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.publishedAt.compareTo(a.publishedAt);
      });
  }

  @override
  Future<void> publish(AnnouncementModel announcement) async {
    await Future.delayed(const Duration(milliseconds: 600));
    _items.add(announcement);
  }

  @override
  Future<void> update(AnnouncementModel announcement) async {
    final index = _items.indexWhere((a) => a.id == announcement.id);
    if (index != -1) _items[index] = announcement;
  }

  @override
  Future<void> delete(String id) async {
    _items.removeWhere((a) => a.id == id);
  }
}
