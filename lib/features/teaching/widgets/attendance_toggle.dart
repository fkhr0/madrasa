import 'package:flutter/material.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/utils/context_extensions.dart';
import '../../attendance/models/attendance_record_model.dart';

/// Three round buttons, P (present), L (late), A (absent), for one student.
class AttendanceToggle extends StatelessWidget {
  final AttendanceStatus value;
  final ValueChanged<AttendanceStatus> onChanged;

  const AttendanceToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _options = [
    (AttendanceStatus.present, 'P'),
    (AttendanceStatus.late, 'L'),
    (AttendanceStatus.absent, 'A'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (status, letter) in _options)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6),
            child: Material(
              color: status == value
                  ? status.color
                  : status.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                onTap: () => onChanged(status),
                child: SizedBox.square(
                  dimension: 36,
                  child: Center(
                    child: Text(
                      letter,
                      style: context.text.titleSmall?.copyWith(
                        color: status == value ? Colors.white : status.color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
