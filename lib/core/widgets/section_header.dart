import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../utils/context_extensions.dart';

/// Title above a group of cards, with an optional "See all" link.
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (onSeeAll != null)
            TextButton(onPressed: onSeeAll, child: Text(AppStrings.seeAll)),
        ],
      ),
    );
  }
}
