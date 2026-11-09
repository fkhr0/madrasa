import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/exam_model.dart';
import '../providers/exam_provider.dart';
import '../widgets/exam_card.dart';
import '../widgets/exam_result_tile.dart';
import '../../../core/l10n/language.dart';

class ExamsPage extends ConsumerWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStudent = ref.watch(currentUserProvider).role == UserRole.student;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Exams')),
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Upcoming')),
              Tab(text: tr('Results')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ExamList(
              value: ref.watch(upcomingExamsProvider),
              emptyTitle: tr('No upcoming exams'),
              itemBuilder: (exam) =>
                  ExamCard(exam: exam, showReminder: isStudent),
            ),
            _ExamList(
              value: ref.watch(pastExamsProvider),
              emptyTitle: tr('No results yet'),
              itemBuilder: (exam) => ExamResultTile(exam: exam),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamList extends StatelessWidget {
  final AsyncValue<List<ExamModel>> value;
  final String emptyTitle;
  final Widget Function(ExamModel exam) itemBuilder;

  const _ExamList({
    required this.value,
    required this.emptyTitle,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AsyncValueView(
      value: value,
      data: (exams) {
        if (exams.isEmpty) {
          return EmptyState(icon: Icons.quiz_outlined, title: emptyTitle);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: exams.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => itemBuilder(exams[i]),
        );
      },
    );
  }
}
