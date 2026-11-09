import 'package:flutter/material.dart';

import '../../../core/widgets/menu_group.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/l10n/language.dart';

/// Which kinds of notifications the user wants.
/// Local only for now; saved to the server in the backend stage.
class NotificationSettingsGroup extends StatefulWidget {
  const NotificationSettingsGroup({super.key});

  @override
  State<NotificationSettingsGroup> createState() =>
      _NotificationSettingsGroupState();
}

class _NotificationSettingsGroupState extends State<NotificationSettingsGroup> {
  bool _assignments = true;
  bool _grades = true;
  bool _messages = true;
  bool _announcements = true;

  @override
  Widget build(BuildContext context) {
    return MenuGroup(
      title: tr('Notifications'),
      children: [
        _switch(
          icon: Icons.assignment_outlined,
          title: tr('Assignments and deadlines'),
          value: _assignments,
          onChanged: (v) => setState(() => _assignments = v),
        ),
        _switch(
          icon: Icons.grade_outlined,
          title: tr('New grades'),
          value: _grades,
          onChanged: (v) => setState(() => _grades = v),
        ),
        _switch(
          icon: Icons.chat_bubble_outline,
          title: tr('Messages'),
          value: _messages,
          onChanged: (v) => setState(() => _messages = v),
        ),
        _switch(
          icon: Icons.campaign_outlined,
          title: tr('Announcements'),
          value: _announcements,
          onChanged: (v) => setState(() => _announcements = v),
        ),
      ],
    );
  }

  Widget _switch({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return MenuTile(
      icon: icon,
      title: title,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
