import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/announcement_model.dart';
import '../providers/announcement_provider.dart';
import '../../../core/l10n/language.dart';

enum _Action { edit, pin, delete }

/// Edit / pin / delete for one announcement. Administrators manage every
/// announcement; teachers only their own. Nothing is shown to others.
class AnnouncementMenu extends ConsumerWidget {
  final AnnouncementModel announcement;

  const AnnouncementMenu({super.key, required this.announcement});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final sure = await confirmDelete(
      context,
      title: tr('Delete this announcement?'),
      message: tr('"{0}" will disappear for everyone.', [announcement.title]),
    );
    if (!sure || !context.mounted) return;

    try {
      await ref.read(announcementActionsProvider).delete(announcement);
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
      return;
    }
    if (!context.mounted) return;
    context.showMessage(tr('Announcement deleted'));
    context.pop();
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(announcementActionsProvider)
          .setPinned(announcement, !announcement.isPinned);
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user.role == UserRole.admin;
    final isAuthor = announcement.isWrittenBy(user.id, user.name);
    if (!isAdmin && !isAuthor) return const SizedBox.shrink();

    return PopupMenuButton<_Action>(
      onSelected: (action) {
        switch (action) {
          case _Action.edit:
            context.push(AppRoutes.editAnnouncement(announcement.id));
          case _Action.pin:
            _togglePin(context, ref);
          case _Action.delete:
            _delete(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: _Action.edit, child: Text(tr('Edit'))),
        if (isAdmin)
          PopupMenuItem(
            value: _Action.pin,
            child: Text(
              announcement.isPinned ? tr('Unpin') : tr('Pin to the top'),
            ),
          ),
        PopupMenuItem(
          value: _Action.delete,
          child: Text(tr('Delete'), style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
