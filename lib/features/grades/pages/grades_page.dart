import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/section_header.dart';
import '../providers/grade_provider.dart';
import '../widgets/overall_average_card.dart';
import '../widgets/subject_grades_card.dart';
import '../widgets/year_result_card.dart';
import '../../../core/l10n/language.dart';

class GradesPage extends ConsumerWidget {
  const GradesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grades = ref.watch(gradesProvider);
    final average = ref.watch(overallAverageProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Grades'))),
      body: AsyncValueView(
        value: grades,
        onRetry: () => ref.invalidate(gradesProvider),
        data: (subjects) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            OverallAverageCard(average: average, subjectCount: subjects.length),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('Year result')),
            YearResultCard(
              results: ref.watch(yearResultsProvider).valueOrNull ?? const [],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('By subject')),
            for (final subject in subjects) ...[
              SubjectGradesCard(grades: subject),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
