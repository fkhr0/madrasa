import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../models/exam_model.dart';
import '../providers/exam_provider.dart';
import '../../../core/l10n/language.dart';

/// One score per student for an exam. Saving publishes them: students and
/// parents see them in Grades. An empty field means no score (e.g. absent).
class ExamScoresPage extends ConsumerWidget {
  final String examId;

  const ExamScoresPage({super.key, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheet = ref.watch(scoreSheetProvider(examId));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Scores'))),
      body: AsyncValueView(
        value: sheet,
        onRetry: () => ref.invalidate(scoreSheetProvider(examId)),
        data: (sheet) => _ScoresForm(exam: sheet.$1, students: sheet.$2),
      ),
    );
  }
}

class _ScoresForm extends ConsumerStatefulWidget {
  final ExamModel exam;
  final List<StudentScoreModel> students;

  const _ScoresForm({required this.exam, required this.students});

  @override
  ConsumerState<_ScoresForm> createState() => _ScoresFormState();
}

class _ScoresFormState extends ConsumerState<_ScoresForm> {
  final _formKey = GlobalKey<FormState>();

  /// Student ID → its score field, filled with the saved score.
  late final Map<String, TextEditingController> _fields = {
    for (final s in widget.students)
      s.id: TextEditingController(text: _plain(s.score)),
  };
  bool _saving = false;

  double get _max => widget.exam.maxScore ?? 100;

  static String _plain(double? n) => n == null
      ? ''
      : n == n.roundToDouble()
      ? '${n.round()}'
      : '$n';

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  String? _validate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final score = double.tryParse(value.trim());
    if (score == null || score < 0) return tr('Invalid');
    if (score > _max) return tr('Max {0}', [_plain(_max)]);
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final scores = {
      for (final MapEntry(:key, :value) in _fields.entries)
        key: double.tryParse(value.text.trim()),
    };

    setState(() => _saving = true);
    try {
      await ref.read(examActionsProvider).saveScores(widget.exam, scores);
      if (!mounted) return;
      final given = scores.values.whereType<double>().length;
      context.showMessage(tr('{0} scores published', [given]));
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final students = widget.students;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(exam.displayTitle, style: context.text.titleMedium),
          Text(
            tr('{0} · {1} · {2} · out of {3}', [
              exam.subject.name,
              exam.className,
              DateFormatter.fullDate(exam.start),
              _plain(_max),
            ]),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('Leave a field empty for a student without a score.'),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, s) in students.indexed) ...[
                  if (i > 0)
                    const Divider(
                      indent: AppSpacing.lg,
                      endIndent: AppSpacing.lg,
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        UserAvatar(name: s.name, size: 34),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            s.name,
                            style: context.text.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 84,
                          child: TextFormField(
                            controller: _fields[s.id],
                            validator: _validate,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '–',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    exam.published ? tr('Save changes') : tr('Publish scores'),
                  ),
          ),
        ],
      ),
    );
  }
}
