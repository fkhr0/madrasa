import 'package:flutter/material.dart';

import '../constants/app_radius.dart';
import '../utils/context_extensions.dart';
import '../utils/date_formatter.dart';

/// Small tinted square with the day number and short month ("12 / NOV").
class DateBlock extends StatelessWidget {
  final DateTime date;
  final Color color;

  const DateBlock({super.key, required this.date, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Text(
            '${date.day}',
            style: context.text.titleLarge?.copyWith(color: color, height: 1.1),
          ),
          Text(
            DateFormatter.monthShort(date).toUpperCase(),
            style: context.text.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
