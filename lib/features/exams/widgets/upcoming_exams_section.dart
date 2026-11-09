import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/section_header.dart';
import '../providers/exam_provider.dart';
import 'exam_card.dart';
import '../../../core/l10n/language.dart';

/// The next exams (default 2), with a link to the Exams page.
class UpcomingExamsSection extends ConsumerWidget {
  final int maxItems;

  const UpcomingExamsSection({super.key, this.maxItems = 2});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exams = ref.watch(upcomingExamsProvider).valueOrNull ?? [];
    if (exams.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: tr('Upcoming exams'),
          onSeeAll: () => context.push(AppRoutes.exams),
        ),
        for (final exam in exams.take(maxItems)) ...[
          ExamCard(exam: exam),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
