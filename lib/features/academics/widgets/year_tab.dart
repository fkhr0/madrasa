import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../institution/models/academic_year_model.dart';
import '../../institution/models/holiday_model.dart';
import '../../institution/providers/institution_provider.dart';
import '../../institution/widgets/year_progress_card.dart';
import 'add_holiday_sheet.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/l10n/language.dart';

/// The study year: progress, semesters and holidays (add / remove).
class YearTab extends ConsumerWidget {
  const YearTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final year = ref.watch(academicYearProvider);

    return AsyncValueView(
      value: year,
      onRetry: () => ref.invalidate(academicYearProvider),
      data: (year) => ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          YearProgressCard(year: year, day: year.clamp(DateTime.now())),
          const SizedBox(height: AppSpacing.xl),

          SectionHeader(title: tr('Semesters')),
          AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                for (final term in year.terms)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            term.name,
                            style: context.text.titleSmall,
                          ),
                        ),
                        // Arabic month names are long: let the dates wrap.
                        Flexible(
                          child: Text(
                            '${DateFormatter.dayMonth(term.start)} – '
                            '${DateFormatter.dayMonth(term.end)}',
                            style: context.text.bodySmall,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: Text(tr('Holidays'), style: context.text.titleMedium),
              ),
              TextButton.icon(
                onPressed: () => showAddHolidaySheet(context, year),
                icon: const Icon(Icons.add, size: 18),
                label: Text(tr('Add')),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final holiday in year.holidays) ...[
            _HolidayTile(holiday: holiday, year: year),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _HolidayTile extends ConsumerWidget {
  final HolidayModel holiday;
  final AcademicYearModel year;

  const _HolidayTile({required this.holiday, required this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dates = holiday.end == null
        ? DateFormatter.dayMonth(holiday.start)
        : '${DateFormatter.dayMonth(holiday.start)} – '
              '${DateFormatter.dayMonth(holiday.lastDay)}';
    final isPast = holiday.lastDay.isBefore(DateTime.now());

    return Opacity(
      opacity: isPast ? 0.55 : 1,
      child: AppCard(
        // Tap to change the name or dates (e.g. when an Eid moves).
        onTap: () => showAddHolidaySheet(context, year, holiday: holiday),
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            IconBox(
              icon: holiday.type.icon,
              color: AppColors.success,
              size: 36,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(holiday.name, style: context.text.titleSmall),
                  Text(
                    holiday.isOfficial ? tr('{0} · Official', [dates]) : dates,
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            // Official holidays can only move, never go away.
            if (holiday.isOfficial)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Tooltip(
                  message: tr(
                    'Official holiday: you can change its dates only',
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: context.palette.textMuted,
                  ),
                ),
              )
            else
              IconButton(
                tooltip: tr('Remove'),
                onPressed: () async {
                  final sure = await confirmDelete(
                    context,
                    title: tr('Remove {0}?', [holiday.name]),
                    message: tr('It becomes a normal school day again.'),
                    action: tr('Remove'),
                  );
                  if (!sure || !context.mounted) return;
                  try {
                    await ref
                        .read(institutionActionsProvider)
                        .removeHoliday(holiday);
                  } on ApiException catch (e) {
                    if (context.mounted) context.showMessage(e.message);
                  }
                },
                icon: Icon(
                  Icons.delete_outline,
                  color: context.palette.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
