import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_summary_model.dart';
import '../providers/attendance_provider.dart';
import '../widgets/attendance_record_tile.dart';
import '../widgets/attendance_summary_card.dart';
import '../../../core/l10n/language.dart';

/// A student's attendance this term. Without [studentId]: the signed-in
/// student or the parent's selected child. The administrator (opening it
/// from People) can tap a day to excuse it or take the excuse back.
class AttendancePage extends ConsumerWidget {
  final String? studentId;

  const AttendancePage({super.key, this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = studentId;
    final records = id == null
        ? ref.watch(attendanceRecordsProvider)
        : ref.watch(studentAttendanceProvider(id));
    final canExcuse =
        id != null && ref.watch(currentUserProvider).role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Attendance'))),
      body: AsyncValueView(
        value: records,
        onRetry: () => id == null
            ? ref.invalidate(attendanceRecordsProvider)
            : ref.invalidate(studentAttendanceProvider(id)),
        data: (records) {
          // Days worth listing: not a plain "present" (late, absent,
          // excused), or present but with missed lessons noted.
          final notable = records
              .where(
                (r) => r.status != AttendanceStatus.present || r.note != null,
              )
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: [
              AttendanceSummaryCard(
                summary: AttendanceSummaryModel.from(records),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (canExcuse) ...[
                _PlannedAbsences(studentId: id),
                const SizedBox(height: AppSpacing.xl),
              ],
              SectionHeader(title: tr('Days to note')),
              if (canExcuse && notable.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    tr('Tap a day to excuse it.'),
                    style: context.text.bodySmall,
                  ),
                ),
              if (notable.isEmpty)
                Text(
                  records.isEmpty
                      ? tr('No attendance taken yet this term.')
                      : tr('Perfect attendance so far. Well done!'),
                  style: context.text.bodyMedium,
                ),
              for (final record in notable) ...[
                AttendanceRecordTile(
                  record: record,
                  onTap: canExcuse
                      ? () => _changeExcuse(context, ref, id, record)
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Office: excuse any day, also ahead (a planned absence).
  static Future<void> excuseAnyDay(
    BuildContext context,
    WidgetRef ref,
    String studentId,
  ) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      helpText: tr('Excuse which day?'),
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (date == null || !context.mounted) return;

    final note = await _askNote(context, DateFormatter.fullDate(date));
    if (note == null || !context.mounted) return;
    try {
      await ref
          .read(attendanceActionsProvider)
          .excuseDay(studentId, date, note);
      if (context.mounted) {
        context.showMessage(
          tr('{0} is excused', [DateFormatter.fullDate(date)]),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  Future<void> _changeExcuse(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    AttendanceRecordModel record,
  ) async {
    final actions = ref.read(attendanceActionsProvider);
    final day = DateFormatter.fullDate(record.date);

    try {
      if (record.status == AttendanceStatus.excused) {
        final sure = await confirmDelete(
          context,
          title: tr('Remove the excuse?'),
          message: tr('{0} goes back to how the teachers marked it.', [day]),
          action: tr('Remove'),
        );
        if (!sure) return;
        await actions.removeExcuse(studentId, record.date);
      } else {
        final note = await _askNote(context, day);
        if (note == null) return;
        await actions.excuseDay(studentId, record.date, note);
      }
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  /// The reason for the excuse, or null when cancelled.
  static Future<String?> _askNote(BuildContext context, String day) {
    final note = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Excuse {0}?', [day])),
        content: TextField(
          controller: note,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: tr('Reason'),
            hintText: tr('e.g. Medical note received'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, note.text.trim()),
            child: Text(tr('Excuse')),
          ),
        ],
      ),
    ).whenComplete(note.dispose);
  }
}

/// Office: excused days still to come, and the button to excuse a day.
class _PlannedAbsences extends ConsumerWidget {
  final String studentId;

  const _PlannedAbsences({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planned =
        ref.watch(plannedExcusesProvider(studentId)).valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: tr('Planned absences')),
        if (planned.isEmpty)
          Text(
            tr(
              'A day the family told you about ahead (a doctor, a trip): teachers still mark it, but the family isn\'t alerted and the day counts as excused.',
            ),
            style: context.text.bodySmall,
          ),
        for (final p in planned)
          AppCard(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormatter.fullDate(p.date),
                        style: context.text.titleSmall,
                      ),
                      if (p.note.isNotEmpty)
                        Text(p.note, style: context.text.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tr('Remove'),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () async {
                    final sure = await confirmDelete(
                      context,
                      title: tr('Remove the excuse?'),
                      message: tr(
                        '{0} becomes a normal school day for this student.',
                        [DateFormatter.fullDate(p.date)],
                      ),
                      action: tr('Remove'),
                    );
                    if (!sure || !context.mounted) return;
                    try {
                      await ref
                          .read(attendanceActionsProvider)
                          .removeExcuse(studentId, p.date);
                    } on ApiException catch (e) {
                      if (context.mounted) context.showMessage(e.message);
                    }
                  },
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => AttendancePage.excuseAnyDay(context, ref, studentId),
          icon: const Icon(Icons.event_busy_outlined, size: 18),
          label: Text(tr('Excuse a day')),
        ),
      ],
    );
  }
}
