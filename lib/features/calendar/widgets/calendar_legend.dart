import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../models/calendar_event_model.dart';

/// What each dot colour means (only the kinds this user can see).
class CalendarLegend extends StatelessWidget {
  final List<CalendarEventType> types;

  const CalendarLegend({super.key, required this.types});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      children: [
        for (final type in types)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(type.label, style: context.text.bodySmall),
            ],
          ),
      ],
    );
  }
}
