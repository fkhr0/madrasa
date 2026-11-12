import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/context_extensions.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../messages/providers/message_provider.dart';
import '../../notifications/widgets/live_alerts_listener.dart';
import '../../notifications/widgets/phone_push_sync.dart';
import '../../realtime/widgets/realtime_sync.dart';
import '../widgets/demo_banner.dart';
import '../widgets/offline_banner.dart';
import '../../../core/l10n/language.dart';

/// Holds the bottom navigation bar. Each tab keeps its own page stack
/// (StatefulShellRoute), so switching tabs never loses your place.
/// The second and third tabs change with the role (see AppRoutes.work).
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      // Tapping the active tab again goes back to its first page.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  static List<Widget> _only(List<int> tabs, List<Widget> all) => [
    for (final i in tabs) all[i],
  ];

  /// Icon, selected icon and label of the second tab for each role.
  static (IconData, IconData, String) _scheduleTab(UserRole role) {
    if (role == UserRole.admin) {
      return (Icons.school_outlined, Icons.school, tr('Academic'));
    }
    if (role == UserRole.driver) {
      return (Icons.route_outlined, Icons.route, tr('Route'));
    }

    return (
      Icons.calendar_today_outlined,
      Icons.calendar_today,
      tr('Schedule'),
    );
  }

  /// Icon, selected icon and label of the third tab for each role.
  static (IconData, IconData, String) _workTab(UserRole role) {
    switch (role) {
      case UserRole.teacher:
        return (Icons.groups_outlined, Icons.groups, tr('Classes'));
      case UserRole.parent:
        return (Icons.insights_outlined, Icons.insights, tr('Progress'));
      case UserRole.admin:
        return (Icons.people_outline, Icons.people, tr('People'));
      case UserRole.driver:
        // Drivers don't see this tab (see _tabsFor).
        return (Icons.route_outlined, Icons.route, tr('Route'));
      case UserRole.student:
        return (Icons.assignment_outlined, Icons.assignment, tr('Assignments'));
    }
  }

  /// Which of the five tabs a role sees. Drivers only need their trip,
  /// their line and the menu: no assignments, students or chats.
  static List<int> _tabsFor(UserRole role) =>
      role == UserRole.driver ? const [0, 1, 4] : const [0, 1, 2, 3, 4];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadMessages = ref.watch(unreadMessagesCountProvider);
    final role = ref.watch(currentUserProvider).role;
    final (scheduleIcon, scheduleSelectedIcon, scheduleLabel) = _scheduleTab(
      role,
    );
    final (workIcon, workSelectedIcon, workLabel) = _workTab(role);
    final tabs = _tabsFor(role);
    final selected = tabs.indexOf(navigationShell.currentIndex);

    // Android's back button on any main tab asks before leaving the app
    // (pages opened on top close normally first).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Leave the app?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Stay')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Leave')),
              ),
            ],
          ),
        );
        if (leave == true) SystemNavigator.pop();
      },
      child: RealtimeSync(
        child: PhonePushSync(
          child: LiveAlertsListener(
            child: Scaffold(
              body: Column(
                children: [
                  const DemoBanner(),
                  const OfflineBanner(),
                  Expanded(child: navigationShell),
                ],
              ),
              bottomNavigationBar: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: context.palette.border),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: selected == -1 ? 0 : selected,
                  onDestinationSelected: (i) => _onTabSelected(tabs[i]),
                  destinations: _only(tabs, [
                    NavigationDestination(
                      icon: const Icon(Icons.home_outlined),
                      selectedIcon: const Icon(Icons.home),
                      label: role == UserRole.driver ? tr('Today') : tr('Home'),
                    ),
                    NavigationDestination(
                      icon: Icon(scheduleIcon),
                      selectedIcon: Icon(scheduleSelectedIcon),
                      label: scheduleLabel,
                    ),
                    NavigationDestination(
                      icon: Icon(workIcon),
                      selectedIcon: Icon(workSelectedIcon),
                      label: workLabel,
                    ),
                    NavigationDestination(
                      icon: Badge(
                        isLabelVisible: unreadMessages > 0,
                        label: Text('$unreadMessages'),
                        child: const Icon(Icons.chat_bubble_outline),
                      ),
                      selectedIcon: const Icon(Icons.chat_bubble),
                      label: tr('Messages'),
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu),
                      selectedIcon: Icon(Icons.menu_open),
                      label: tr('More'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
