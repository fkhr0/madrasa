import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../auth/models/user_model.dart';

class RoleChips extends StatelessWidget {
  static const roles = [
    UserRole.student,
    UserRole.teacher,
    UserRole.parent,
    UserRole.driver,
  ];

  final UserRole selected;
  final ValueChanged<UserRole> onSelected;

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
                label: Text(plural ? role.pluralLabel : role.label),
                selected: role == selected,
                onSelected: (_) => onSelected(role),
              ),
            ),
        ],
      ),
    );
  }
}
