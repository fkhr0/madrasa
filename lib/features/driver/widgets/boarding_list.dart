import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../transport/models/route_student_model.dart';
import '../../transport/models/trip_model.dart';
import '../../transport/providers/transport_provider.dart';
import '../../../core/l10n/language.dart';

/// Students to pick up (or drop off) at the current stop.
/// The driver taps ✓ on board or ✗ absent; parents are told right away.
class BoardingList extends ConsumerWidget {
  final String routeId;
  final TripModel trip;
  final List<RouteStudentModel> students;

  const BoardingList({
    super.key,
    required this.routeId,
    required this.trip,
    required this.students,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (students.isEmpty) {
      return Text(
        tr('No students at this stop.'),
        style: context.text.bodyMedium,
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < students.length; i++) ...[
            if (i > 0)
              const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
            _StudentRow(routeId: routeId, trip: trip, student: students[i]),
          ],
        ],
      ),
    );
  }
}

class _StudentRow extends ConsumerWidget {
  final String routeId;
  final TripModel trip;
  final RouteStudentModel student;

  const _StudentRow({
    required this.routeId,
    required this.trip,
    required this.student,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = trip.statusOf(student);
    final actions = ref.read(transportActionsProvider);
    final canMark = status != BoardingStatus.notRiding;

    void mark(BoardingStatus s) => actions.setBoarding(routeId, student.id, s);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          UserAvatar(name: student.name, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: context.text.titleSmall),
                const SizedBox(height: 2),
                StatusBadge(label: status.label, color: status.color),
              ],
            ),
          ),
          if (canMark) ...[
            _RoundButton(
              icon: Icons.check,
              color: AppColors.success,
              selected: status == BoardingStatus.onBoard,
              tooltip: tr('On the bus'),
              onTap: () => mark(
                status == BoardingStatus.onBoard
                    ? BoardingStatus.waiting
                    : BoardingStatus.onBoard,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _RoundButton(
              icon: Icons.close,
              color: AppColors.danger,
              selected: status == BoardingStatus.absent,
              tooltip: tr('Not at the stop'),
              onTap: () => mark(
                status == BoardingStatus.absent
                    ? BoardingStatus.waiting
                    : BoardingStatus.absent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _RoundButton({
    required this.icon,
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? color : color.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 20, color: selected ? Colors.white : color),
          ),
        ),
      ),
    );
  }
}
