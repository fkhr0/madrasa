import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../academics/providers/academics_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/announcement_model.dart';
import '../providers/announcement_provider.dart';
import '../../../core/l10n/language.dart';

/// Teachers announce to their own classes; administrators to the whole
/// school, a class, all parents or all teachers, and can pin or schedule.
/// With [announcementId] it edits that announcement instead.
class NewAnnouncementPage extends ConsumerStatefulWidget {
  final String? announcementId;

  const NewAnnouncementPage({super.key, this.announcementId});

  @override
  ConsumerState<NewAnnouncementPage> createState() =>
      _NewAnnouncementPageState();
}

class _NewAnnouncementPageState extends ConsumerState<NewAnnouncementPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  late final bool _isAdmin =
      ref.read(currentUserProvider).role == UserRole.admin;

  late AnnouncementAudience _audience = _isAdmin
      ? AnnouncementAudience.school
      : AnnouncementAudience.className;
  String? _className;
  bool _isPinned = false;

  /// Null = publish now.
  DateTime? _scheduledFor;
  bool _isSaving = false;

  /// The announcement being edited, once loaded.
  AnnouncementModel? _editing;

  bool get _isNew => widget.announcementId == null;

  void _fill(AnnouncementModel a) {
    _editing = a;
    _title.text = a.title;
    _body.text = a.body;
    _audience = a.audience;
    _className = a.className;
    _isPinned = a.isPinned;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 30),
    );
    if (time == null) return;

    setState(
      () => _scheduledFor = date.copyWith(hour: time.hour, minute: time.minute),
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_audience == AnnouncementAudience.className && _className == null) {
      context.showMessage(tr('Choose a class'));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _save();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showMessage(e.message);
    }
  }

  Future<void> _save() async {
    final actions = ref.read(announcementActionsProvider);

    if (_editing case final old?) {
      await actions.update(
        old.copyWith(
          title: _title.text.trim(),
          body: _body.text.trim(),
          audience: _audience,
          className: _className,
          isPinned: _isPinned,
        ),
      );
      if (!mounted) return;
      context.showMessage(tr('Announcement updated'));
      Navigator.of(context).pop();
      return;
    }

    await actions.publish(
      AnnouncementModel(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        body: _body.text.trim(),
        authorName: ref.read(currentUserProvider).name,
        authorId: ref.read(currentUserProvider).id,
        audience: _audience,
        className: _audience == AnnouncementAudience.className
            ? _className
            : null,
        publishedAt: _scheduledFor ?? DateTime.now(),
        isPinned: _isPinned,
      ),
    );

    if (!mounted) return;
    context.showMessage(
      _scheduledFor == null
          ? tr('Announcement published')
          : tr('Scheduled for {0}, {1}', [
              DateFormatter.relativeDay(_scheduledFor!),
              DateFormatter.time(_scheduledFor!),
            ]),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.announcementId;
    if (id != null && _editing == null) {
      final loaded = ref.watch(announcementByIdProvider(id)).valueOrNull;
      if (loaded == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      _fill(loaded);
    }

    // Admins choose from every class; teachers only from their own.
    final classNames = _isAdmin
        ? [
            for (final c in ref.watch(schoolClassesProvider).valueOrNull ?? [])
              c.name,
          ]
        : [
            for (final c in ref.watch(myClassesProvider).valueOrNull ?? [])
              c.name,
          ];

    final audiences = _isAdmin
        ? AnnouncementAudience.values
        : const [AnnouncementAudience.className];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr('New announcement') : tr('Edit announcement')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            Text(tr('Send to'), style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final audience in audiences)
                  ChoiceChip(
                    avatar: Icon(audience.icon, size: 16),
                    label: Text(audience.label),
                    selected: _audience == audience,
                    onSelected: (_) => setState(() => _audience = audience),
                  ),
              ],
            ),
            if (_audience == AnnouncementAudience.className) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final name in classNames)
                    ChoiceChip(
                      label: Text(name),
                      selected: _className == name,
                      onSelected: (_) => setState(() => _className = name),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.xl),

            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('Add a title') : null,
              decoration: InputDecoration(labelText: tr('Title')),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _body,
              minLines: 5,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? tr('Write the message')
                  : null,
              decoration: InputDecoration(
                labelText: tr('Message'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            if (_isAdmin)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Pin to the top')),
                subtitle: Text(tr('For important notices')),
                value: _isPinned,
                onChanged: (v) => setState(() => _isPinned = v),
              ),
            if (_isNew) ...[
              OutlinedButton.icon(
                onPressed: _pickSchedule,
                icon: const Icon(Icons.schedule_send_outlined, size: 18),
                label: Text(
                  _scheduledFor == null
                      ? tr('Tap to schedule, or publish at a set time')
                      : tr('Scheduled: {0}, {1}', [
                          DateFormatter.relativeDay(_scheduledFor!),
                          DateFormatter.time(_scheduledFor!),
                        ]),
                ),
              ),
              if (_scheduledFor != null)
                TextButton(
                  onPressed: () => setState(() => _scheduledFor = null),
                  child: Text(tr('Publish now instead')),
                ),
            ],
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _isSaving ? null : _publish,
              child: _isSaving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      !_isNew
                          ? tr('Save changes')
                          : _scheduledFor == null
                          ? tr('Publish now')
                          : tr('Schedule the announcement'),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('Everyone it is sent to gets a notification.'),
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
