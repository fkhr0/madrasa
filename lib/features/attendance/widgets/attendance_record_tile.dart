import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/attendance_record_model.dart';

class AttendanceRecordTile extends StatelessWidget {
  final AttendanceRecordModel record;
  final VoidCallback? onTap;

  const AttendanceRecordTile({super.key, required this.record, this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = record.status;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBox(icon: status.icon, color: status.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormatter.fullDate(record.date),
                  style: context.text.titleSmall,
                ),
                if (record.note != null)
                  Text(record.note!, style: context.text.bodySmall),
              ],
            ),
          ),
          StatusBadge(label: status.label, color: status.color),
        ],
      ),
    );
  }
}
