import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../people/providers/people_provider.dart';
import '../../../core/l10n/language.dart';

/// What was picked: a teacher, or "no teacher".
class TeacherChoice {
  /// Null = no teacher.
  final UserModel? teacher;

  const TeacherChoice(this.teacher);
}

/// Picks a teacher of the school. Teachers of [subjectName] are listed
/// first. Returns null when the sheet is closed without choosing.
Future<TeacherChoice?> showTeacherPicker(
  BuildContext context, {
  required String title,
  String? subjectName,
  String? currentId,
  bool allowNone = true,
}) {
  return showModalBottomSheet<TeacherChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TeacherPicker(
      title: title,
      subjectName: subjectName,
      currentId: currentId,
      allowNone: allowNone,
    ),
  );
}

class _TeacherPicker extends ConsumerWidget {
  final String title;
  final String? subjectName;
  final String? currentId;
  final bool allowNone;

  const _TeacherPicker({
    required this.title,
    required this.subjectName,
    required this.currentId,
    required this.allowNone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teachers =
        ref.watch(peopleByRoleProvider(UserRole.teacher)).valueOrNull ?? [];
    final sorted = [
      ...teachers.where((t) => t.subjectName == subjectName),
      ...teachers.where((t) => t.subjectName != subjectName),
    ].where((t) => t.isActive).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
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
              child: Text(title, style: context.text.titleLarge),
            ),
            if (allowNone)
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: Text(tr('No teacher')),
                trailing: currentId == null ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, const TeacherChoice(null)),
              ),
            for (final teacher in sorted)
              ListTile(
                leading: UserAvatar(name: teacher.name, size: 36),
                title: Text(teacher.name),
                subtitle: Text(teacher.subjectName ?? ''),
                trailing: teacher.id == currentId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, TeacherChoice(teacher)),
              ),
          ],
        ),
      ),
    );
  }
}
