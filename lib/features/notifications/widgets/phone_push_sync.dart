import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language.dart';
import '../../../core/push/phone_push.dart';
import '../../../core/push/web_push.dart';
import '../../../core/utils/context_extensions.dart';
import 'phone_notifications_card.dart';
import '../providers/notification_provider.dart';

/// Phone notifications while someone is signed in.
class PhonePushSync extends ConsumerStatefulWidget {
  final Widget child;

  const PhonePushSync({super.key, required this.child});

  @override
  ConsumerState<PhonePushSync> createState() => _PhonePushSyncState();
}

class _PhonePushSyncState extends ConsumerState<PhonePushSync> {
  final _subscriptions = <StreamSubscription<Object>>[];

  @override
  void initState() {
    super.initState();
    final repository = ref.read(notificationRepositoryProvider);
    _register(() => repository.registerThisPhone());
    WidgetsBinding.instance.addPostFrameCallback((_) => _askOnce());
    if (!PhonePush.supported) return;

    _subscriptions
      ..add(
        PhonePush.idChanges.listen(
          (id) => _register(() => repository.registerThisPhone(id)),
        ),
      )
      ..add(PhonePush.taps.listen(_open))
      ..add(
        PhonePush.whileOpen.listen(
          (_) => ref.invalidate(notificationsProvider),
        ),
      );
    // The app was opened by tapping a notification.
    PhonePush.openedFrom().then((route) {
      if (route != null) _open(route);
    });
  }

  /// The first time the app opens signed in: what notifications are for, and a
  /// button to allow them (the system then asks).
  Future<void> _askOnce() async {
    if (!AppConfig.useApi || (!kIsWeb && !PhonePush.supported)) return;
    final permission = kIsWeb
        ? webPushPermission
        : await PhonePush.permission();
    if (permission != 'default' || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);
    if (!mounted) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: Text(tr('Get notifications on this phone')),
        content: Text(
          tr(
            'The bus, absences, grades, messages and school news, even when the app is closed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Not now')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Turn on')),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final message = await turnOnNotifications(ref);
    if (mounted) context.showMessage(message);
  }

  static const _askedKey = 'notifications.asked';

  /// Offline now: the next app start tries again.
  Future<void> _register(Future<void> Function() send) async {
    try {
      await send();
    } catch (_) {}
  }

  /// A tab (or a chat inside Messages) is opened in place; any other page
  /// on top of the app, so back returns to it instead of closing the app.
  void _open(String route) {
    if (!mounted || !route.startsWith('/')) return;
    const tabs = [
      AppRoutes.home,
      AppRoutes.schedule,
      AppRoutes.work,
      AppRoutes.messages,
      AppRoutes.more,
    ];
    final inTab = tabs.any((t) => route == t || route.startsWith('$t/'));
    inTab ? context.go(route) : context.push(route);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
