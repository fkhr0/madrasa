import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/info_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../timetable/providers/timetable_provider.dart';
import '../models/school_class_model.dart';
import '../models/school_subject_model.dart';
import '../providers/academics_provider.dart';
import '../widgets/class_sheet.dart';
import '../widgets/teacher_picker_sheet.dart';
import '../../../core/l10n/language.dart';

/// One class, fully managed here: its head teacher, the subjects it
/// studies and who teaches each one. The pencil renames or deletes it.
class SchoolClassPage extends ConsumerWidget {
  final String classId;

  const SchoolClassPage({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolClass = ref.watch(schoolClassByIdProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: Text(schoolClass.valueOrNull?.name ?? ''),
        actions: [
          if (schoolClass.valueOrNull case final loaded?)
            IconButton(
              tooltip: tr('Edit class'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final deleted = await showClassSheet(
                  context,
                  schoolClass: loaded,
                );
                if (deleted == true && context.mounted) {
                  context.showMessage(tr('{0} deleted', [loaded.name]));
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: AsyncValueView(
        value: schoolClass,
        data: (schoolClass) => schoolClass == null
            ? EmptyState(icon: Icons.search_off, title: tr('Class not found'))
            : _ClassBody(schoolClass: schoolClass),
      ),
    );
  }
}

class _ClassBody extends ConsumerWidget {
  final SchoolClassModel schoolClass;

  const _ClassBody({required this.schoolClass});

  /// Runs an action and shows the server's message if it fails.
  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  Future<void> _changeHead(BuildContext context, WidgetRef ref) async {
    final choice = await showTeacherPicker(
      context,
      title: tr('Head of {0}', [schoolClass.name]),
      currentId: schoolClass.homeroomTeacherId,
    );
    if (choice == null || !context.mounted) return;

    await _run(
      context,
      () => ref
          .read(academicsActionsProvider)
          .saveClass(
            classId: schoolClass.id,
            name: schoolClass.name,
            homeroomTeacherId: choice.teacher?.id,
          ),
    );
  }

  Future<void> _addSubject(
    BuildContext context,
    WidgetRef ref,
    List<SchoolSubjectModel> missing,
  ) async {
    final subject = await showModalBottomSheet<SchoolSubjectModel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Text(tr('Add a subject'), style: context.text.titleLarge),
            ),
            for (final s in missing)
              ListTile(
                leading: Icon(s.icon, color: s.color),
                title: Text(s.name),
                onTap: () => Navigator.pop(sheetContext, s),
              ),
          ],
        ),
      ),
    );
    if (subject == null || !context.mounted) return;

    await _run(
      context,
      () => ref
          .read(academicsActionsProvider)
          .setSubjectTeacher(
            classId: schoolClass.id,
            subjectId: subject.id,
            teacherId: null,
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(schoolSubjectsProvider).valueOrNull ?? [];
    final taught = {for (final s in schoolClass.subjects) s.subjectId};
    final missing = catalogue.where((s) => !taught.contains(s.id)).toList();
    SchoolSubjectModel? styleOf(String id) {
      for (final s in catalogue) {
        if (s.id == id) return s;
      }
      return null;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            children: [
              InfoRow(
                icon: Icons.people_outline,
                label: tr('Students'),
                value: '${schoolClass.studentCount}',
              ),
              InkWell(
                onTap: () => _changeHead(context, ref),
                child: Row(
                  children: [
                    Expanded(
                      child: InfoRow(
                        icon: Icons.star_outline,
                        label: tr('Head teacher'),
                        value:
                            schoolClass.homeroomTeacherName ??
                            tr('Not chosen — tap to choose'),
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
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _TimetableCard(schoolClass: schoolClass),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () => context.push(AppRoutes.takeAttendance(schoolClass.id)),
          child: Row(
            children: [
              IconBox(
                icon: Icons.fact_check_outlined,
                color: context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Attendance'), style: context.text.titleSmall),
                    Text(
                      tr('Take or correct any lesson'),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () => context.push(AppRoutes.classExams(schoolClass.id)),
          child: Row(
            children: [
              IconBox(
                icon: Icons.assignment_outlined,
                color: context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Exams'), style: context.text.titleSmall),
                    Text(
                      tr('Mid-year and final exams, scores of every subject'),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () => context.push(AppRoutes.classAssignments(schoolClass.id)),
          child: Row(
            children: [
              IconBox(
                icon: Icons.task_outlined,
                color: context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Homework'), style: context.text.titleSmall),
                    Text(
                      tr('Work of every subject, hand-ins and grades'),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          onTap: () => context.push(AppRoutes.classResources(schoolClass.id)),
          child: Row(
            children: [
              IconBox(
                icon: Icons.menu_book_outlined,
                color: context.palette.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Study material'), style: context.text.titleSmall),
                    Text(
                      tr('Notes, slides, videos and links for the class'),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.palette.textMuted),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(
          title: tr('Subjects ({0})', [schoolClass.subjects.length]),
        ),
        if (schoolClass.subjects.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              tr('This class has no subjects yet.'),
              style: context.text.bodyMedium,
            ),
          ),
        for (final subject in schoolClass.subjects) ...[
          _SubjectTeacherTile(
            subject: subject,
            style: styleOf(subject.subjectId),
            onChangeTeacher: () async {
              final choice = await showTeacherPicker(
                context,
                title: tr('{0} teacher', [subject.subjectName]),
                subjectName: subject.subjectName,
                currentId: subject.teacherId,
              );
              if (choice == null || !context.mounted) return;
              await _run(
                context,
                () => ref
                    .read(academicsActionsProvider)
                    .setSubjectTeacher(
                      classId: schoolClass.id,
                      subjectId: subject.subjectId,
                      teacherId: choice.teacher?.id,
                    ),
              );
            },
            onRemove: () async {
              final sure = await confirmDelete(
                context,
                title: tr('Remove {0}?', [subject.subjectName]),
                message: tr(
                  '{0} will no longer study it, and its lessons leave the timetable. The subject stays in the school\'s list.',
                  [schoolClass.name],
                ),
                action: tr('Remove'),
              );
              if (!sure || !context.mounted) return;
              await _run(
                context,
                () => ref
                    .read(academicsActionsProvider)
                    .removeSubjectFromClass(
                      classId: schoolClass.id,
                      subjectId: subject.subjectId,
                    ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (missing.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _addSubject(context, ref, missing),
            icon: const Icon(Icons.add),
            label: Text(tr('Add a subject')),
          ),
      ],
    );
  }
}

/// Opens the class's weekly timetable.
class _TimetableCard extends ConsumerWidget {
  final SchoolClassModel schoolClass;

  const _TimetableCard({required this.schoolClass});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(classTimetableProvider(schoolClass.id)).valueOrNull;

    return AppCard(
      onTap: () => context.push(AppRoutes.classTimetable(schoolClass.id)),
      child: Row(
        children: [
          IconBox(
            icon: Icons.calendar_view_week,
            color: context.palette.primary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Timetable'), style: context.text.titleSmall),
                Text(switch (week?.lessons.length) {
                  null => tr('Loading…'),
                  0 => tr('No lessons placed yet – tap to plan the week'),
                  final n => tr('{0} lessons a week', [n]),
                }, style: context.text.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: context.palette.textMuted),
        ],
      ),
    );
  }
}

class _SubjectTeacherTile extends StatelessWidget {
  final ClassSubjectModel subject;

  /// The subject's icon and colour, from the school's list.
  final SchoolSubjectModel? style;
  final VoidCallback onChangeTeacher;
  final VoidCallback onRemove;

  const _SubjectTeacherTile({
    required this.subject,
    required this.style,
    required this.onChangeTeacher,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = style?.color ?? context.palette.primary;

    return AppCard(
      onTap: onChangeTeacher,
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        0,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconBox(
            icon: style?.icon ?? Icons.menu_book_outlined,
            color: color,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject.subjectName, style: context.text.titleSmall),
                Text(
                  subject.teacherName ?? tr('No teacher yet – tap to assign'),
                  style: context.text.bodySmall?.copyWith(
                    color: subject.hasTeacher ? null : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) =>
                action == 'teacher' ? onChangeTeacher() : onRemove(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'teacher',
                child: Text(tr('Change teacher')),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  tr('Remove from class'),
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
