import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../assignments/models/attachment_model.dart';
import '../../assignments/widgets/attachment_tile.dart';
import '../../files/providers/file_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/resource_model.dart';
import '../providers/resource_provider.dart';
import '../widgets/resource_tile.dart';
import '../../../core/l10n/language.dart';

/// A class's study material for the subject's teacher (every subject for
/// the office): share a file or a link, or remove one.
class ClassResourcesPage extends ConsumerWidget {
  final String classId;

  const ClassResourcesPage({super.key, required this.classId});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ResourceModel resource,
  ) async {
    final sure = await confirmDelete(
      context,
      title: tr('Remove {0}?', [resource.title]),
      message: tr('Students no longer see it.'),
      action: tr('Remove'),
    );
    if (!sure || !context.mounted) return;
    try {
      await ref.read(resourceActionsProvider).delete(resource, classId);
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final material = ref.watch(classResourcesProvider(classId));
    final (className, subjects) = ref.watch(
      classSubjectChoicesProvider(classId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(tr('Study material · {0}', [className]))),
      floatingActionButton: subjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) =>
                    _ShareSheet(classId: classId, subjects: subjects),
              ),
              icon: const Icon(Icons.add),
              label: Text(tr('Share')),
            ),
      body: AsyncValueView(
        value: material,
        onRetry: () => ref.invalidate(classResourcesProvider(classId)),
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.menu_book_outlined,
                title: tr('Nothing shared yet'),
                message: tr(
                  'Share notes, slides, videos or links with the class.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  96, // room for the button
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => ResourceTile(
                  resource: items[i],
                  trailing: IconButton(
                    tooltip: tr('Remove'),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.danger,
                    ),
                    onPressed: () => _delete(context, ref, items[i]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ShareSheet extends ConsumerStatefulWidget {
  final String classId;
  final List<(String, String)> subjects;

  const _ShareSheet({required this.classId, required this.subjects});

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  late String? _subjectId = widget.subjects.length == 1
      ? widget.subjects.single.$1
      : null;

  /// What a teacher can share (older "slides" items still show in lists).
  static const _types = [
    ResourceType.pdf,
    ResourceType.video,
    ResourceType.link,
  ];

  ResourceType _type = ResourceType.pdf;
  final _title = TextEditingController();
  final _url = TextEditingController();
  AttachmentModel? _file;
  bool _busy = false;

  /// A video: a file from the phone, or a link (YouTube...) for long ones.
  bool _videoAsLink = false;

  bool get _isLink =>
      _type == ResourceType.link ||
      (_type == ResourceType.video && _videoAsLink);

  /// The file kinds to pick for this type.
  List<String> get _extensions =>
      _type == ResourceType.video ? videoExtensions : const ['pdf'];

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _busy = true);
    final files = await pickAndUpload(context, ref, extensions: _extensions);
    if (!mounted) return;
    // The title stays what the teacher writes (never the file's name).
    setState(() {
      _busy = false;
      if (files.isNotEmpty) _file = files.first;
    });
  }

  Future<void> _share() async {
    final subjectId = _subjectId;
    final title = _title.text.trim();
    final url = _url.text.trim();
    if (subjectId == null) return context.showMessage(tr('Choose the subject'));
    if (title.length < 2) return context.showMessage(tr('Write a title'));
    if (_isLink && !url.startsWith('http')) {
      return context.showMessage(tr('Paste a link that starts with https://'));
    }
    if (!_isLink && _file == null) {
      return context.showMessage(tr('Choose a file'));
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(resourceActionsProvider)
          .add(
            classId: widget.classId,
            subjectId: subjectId,
            title: title,
            type: _type,
            fileId: _isLink ? null : _file!.id,
            url: _isLink ? url : null,
          );
      if (!mounted) return;
      Navigator.pop(context);
      context.showMessage(tr('Shared with the class'));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Share material'), style: context.text.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            if (widget.subjects.length > 1) ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final (id, name) in widget.subjects)
                    ChoiceChip(
                      label: Text(name),
                      selected: _subjectId == id,
                      onSelected: (_) => setState(() => _subjectId = id),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final type in _types)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18, color: type.color),
                    label: Text(type.label),
                    selected: _type == type,
                    // A file of another kind doesn't fit the new type.
                    onSelected: (_) => setState(() {
                      _type = type;
                      _file = null;
                    }),
                  ),
              ],
            ),
            if (_type == ResourceType.video) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(tr('From the phone')),
                    selected: !_videoAsLink,
                    onSelected: (_) => setState(() => _videoAsLink = false),
                  ),
                  ChoiceChip(
                    label: Text(tr('A link (YouTube…)')),
                    selected: _videoAsLink,
                    onSelected: (_) => setState(() {
                      _videoAsLink = true;
                      _file = null;
                    }),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tr('Title'),
                hintText: tr('e.g. Chapter 3 summary'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_isLink)
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: tr('Link'),
                  hintText: tr('https://…'),
                ),
              )
            else if (_file case final file?)
              AttachmentTile(
                attachment: file,
                onRemove: () async {
                  final sure = await confirmDelete(
                    context,
                    title: tr('Remove {0}?', [file.name]),
                    action: tr('Remove'),
                  );
                  if (sure) setState(() => _file = null);
                },
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _pick,
                icon: const Icon(Icons.attach_file, size: 18),
                label: Text(_busy ? tr('Uploading…') : tr('Choose a file')),
              ),
            // The limit, before choosing (not after a long wait).
            if (!_isLink && _file == null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _type == ResourceType.video
                    ? tr(
                        'MP4 video, up to {0} MB. For longer videos, share a YouTube link.',
                        [maxVideoMb],
                      )
                    : tr('PDF file, up to {0} MB.', [maxFileMb]),
                style: context.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy ? null : _share,
              child: Text(tr('Share with the class')),
            ),
          ],
        ),
      ),
    );
  }
}
