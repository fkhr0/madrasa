import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../auth/models/user_model.dart';

/// The roles an administrator manages, as chips that scroll sideways
/// (four labels don't fit a segmented button on small phones).
class RoleChips extends StatelessWidget {
  static const roles = [
    UserRole.student,
    UserRole.teacher,
    UserRole.parent,
    UserRole.driver,
  ];

  final UserRole selected;
  final ValueChanged<UserRole> onSelected;

  /// "Students" instead of "Student".
  final bool plural;

  const RoleChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.plural = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final role in roles)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(plural ? '${role.label}s' : role.label),
                selected: role == selected,
                onSelected: (_) => onSelected(role),
              ),
            ),
        ],
      ),
    );
  }
}
