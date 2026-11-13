import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/push/phone_push.dart';
import '../../../core/push/web_push.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../providers/notification_provider.dart';
import '../../../core/l10n/language.dart';

/// "Get notifications on this phone": asks once, so the bus, announcements and
/// the rest reach the phone even when the app is closed.
class PhoneNotificationsCard extends ConsumerStatefulWidget {
  const PhoneNotificationsCard({super.key});

  @override
  ConsumerState<PhoneNotificationsCard> createState() =>
      _PhoneNotificationsCardState();
}

class _PhoneNotificationsCardState
    extends ConsumerState<PhoneNotificationsCard> {
  bool _asking = false;

  /// "granted", "denied" or "default"; null while it is being read.
  String? _permission;

  @override
  void initState() {
    super.initState();
    _readPermission();
  }

  /// The Android app asks Firebase; the browser knows at once.
  Future<void> _readPermission() async {
    final permission = PhonePush.supported
        ? await PhonePush.permission()
        : webPushPermission;
    if (mounted) setState(() => _permission = permission);
  }

  Future<void> _turnOn() async {
    setState(() => _asking = true);
    final message = await turnOnNotifications(ref);
    if (!mounted) return;
    setState(() => _asking = false);
    await _readPermission();
    if (mounted) context.showMessage(message);
  }

  @override
  Widget build(BuildContext context) {
    final permission = _permission;
    if (!AppConfig.useApi || permission == null || permission == 'granted') {
      return const SizedBox.shrink();
    }
    // The installed app without Firebase can't offer anything (and the
    // iPhone advice below is for the browser).
    if (!kIsWeb && !PhonePush.supported) return const SizedBox.shrink();

    final String title;
    final String detail;
    Widget? action;
    if (!PhonePush.supported && !webPushSupported) {
      title = tr('Notifications when the app is closed');
      detail = tr(
        'On iPhone: tap Share, then "Add to Home Screen", and open the '
        'app from there.',
      );
    } else if (permission == 'denied') {
      title = tr('Notifications are blocked');
      detail = PhonePush.supported
          ? tr(
              "Open the phone's Settings, then Apps, Madrasa, Notifications, "
              'and allow them.',
            )
          : tr(
              'Tap the lock or "aA" next to the address, allow Notifications, '
              'then come back here.',
            );
    } else {
      title = tr('Get notifications on this phone');
      detail = tr(
        'The bus, announcements and more, even when the app is closed.',
      );
      action = FilledButton(
        // The theme makes buttons full width; inside this row that breaks
        // the layout (a grey box over the whole page in the release app).
        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
        onPressed: _asking ? null : _turnOn,
        child: Text(tr('Turn on')),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: AppCard(
        color: AppColors.info.withValues(alpha: 0.08),
        borderColor: Colors.transparent,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const IconBox(
              icon: Icons.notifications_active_outlined,
              color: AppColors.info,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleSmall),
                  Text(detail, style: context.text.bodySmall),
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for notifications and says how it went (the card and the first-open
/// question use it).
Future<String> turnOnNotifications(WidgetRef ref) async {
  try {
    final on = await ref
        .read(notificationRepositoryProvider)
        .turnOnPhoneNotifications();
    return on
        ? tr('Notifications are on for this phone')
        : tr('Notifications were not turned on');
  } on TimeoutException {
    // Allowed, but Firebase hasn't answered yet: it registers by itself.
    return tr(
      'Notifications are allowed. The phone is still connecting; they will start in a moment.',
    );
  } catch (_) {
    return tr('Notifications were not turned on');
  }
}
