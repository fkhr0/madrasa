import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/announcement_model.dart';
import '../repo/announcement_repository.dart';
import '../repo/api_announcement_repository.dart';
import '../repo/mock_announcement_repository.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>(
  (ref) => AppConfig.useApi
      ? ApiAnnouncementRepository(watchApi(ref))
      : MockAnnouncementRepository(),
);

final announcementsProvider = FutureProvider<List<AnnouncementModel>>((
  ref,
) async {
  final role = ref.watch(currentUserProvider).role;
  final all = await ref.watch(announcementRepositoryProvider).getAll();

  bool isFor(AnnouncementAudience audience) {
    switch (audience) {
      case AnnouncementAudience.school:
      case AnnouncementAudience.className:
        return true;
      case AnnouncementAudience.parents:
        return role == UserRole.parent || role == UserRole.admin;
      case AnnouncementAudience.teachers:
        return role == UserRole.teacher || role == UserRole.admin;
    }
  }

  return all.where((a) => isFor(a.audience)).toList();
});

final announcementByIdProvider =
    FutureProvider.family<AnnouncementModel?, String>((ref, id) async {
      final all = await ref.watch(announcementsProvider.future);

      for (final announcement in all) {
        if (announcement.id == id) return announcement;
      }

      return null;
    });

final announcementActionsProvider = Provider<AnnouncementActions>(
  AnnouncementActions.new,
);

class AnnouncementActions {
  final Ref _ref;

  AnnouncementActions(this._ref);

  AnnouncementRepository get _repository =>
      _ref.read(announcementRepositoryProvider);

  Future<void> publish(AnnouncementModel announcement) async {
    await _repository.publish(announcement);
    _ref.invalidate(announcementsProvider);
  }

  Future<void> update(AnnouncementModel announcement) async {
    await _repository.update(announcement);
    _ref.invalidate(announcementsProvider);
  }

  Future<void> setPinned(AnnouncementModel announcement, bool pinned) =>
      update(announcement.copyWith(isPinned: pinned));

  Future<void> delete(AnnouncementModel announcement) async {
    await _repository.delete(announcement.id);
    _ref.invalidate(announcementsProvider);
  }
}
