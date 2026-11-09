import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/icon_box.dart';
import '../providers/academics_provider.dart';
import '../widgets/class_sheet.dart';
import '../widgets/subject_sheet.dart';
import '../widgets/school_class_tile.dart';
import '../widgets/year_tab.dart';
import '../../../core/l10n/language.dart';

/// Administrator's second tab: the study year, classes and subjects.
class AcademicsPage extends StatelessWidget {
  const AcademicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: _AppBar(),
        body: TabBarView(children: [YearTab(), _ClassesTab(), _SubjectsTab()]),
      ),
    );
  }
}

class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  const _AppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 48);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(tr('Academic')),
      actions: [
        IconButton(
          tooltip: tr('Bell times'),
          icon: const Icon(Icons.schedule),
          onPressed: () => context.push(AppRoutes.bellTimes),
        ),
      ],
      bottom: TabBar(
        tabs: [
          Tab(text: tr('Year')),
          Tab(text: tr('Classes')),
          Tab(text: tr('Subjects')),
        ],
      ),
    );
  }
}

class _ClassesTab extends ConsumerWidget {
  const _ClassesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(schoolClassesProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showClassSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Class')),
      ),
      body: AsyncValueView(
        value: classes,
        onRetry: () => ref.invalidate(schoolClassesProvider),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            96, // room for the button
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => SchoolClassTile(schoolClass: items[i]),
        ),
      ),
    );
  }
}

class _SubjectsTab extends ConsumerWidget {
  const _SubjectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(schoolSubjectsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSubjectSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Subject')),
      ),
      body: AsyncValueView(
        value: subjects,
        onRetry: () => ref.invalidate(schoolSubjectsProvider),
        data: (items) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.page,
            AppSpacing.page,
            96, // room for the button
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, i) => AppCard(
            onTap: () => showSubjectSheet(context, subject: items[i]),
            child: Row(
              children: [
                IconBox(icon: items[i].icon, color: items[i].color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].name, style: context.text.titleSmall),
                      Text(
                        items[i].classCount == 1
                            ? tr('Studied in 1 class')
                            : tr('Studied in {0} classes', [
                                items[i].classCount,
                              ]),
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: context.palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
