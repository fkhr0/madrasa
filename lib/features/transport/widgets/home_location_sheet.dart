import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/location_link.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/location_picker.dart';
import '../models/student_home_model.dart';
import '../providers/transport_provider.dart';
import '../repo/transport_repository.dart';
import 'place_search_field.dart';
import '../../../core/l10n/language.dart';

/// "Where is Zainab's home?", for door-to-door pick-up.
Future<StudentHomeModel?> showHomeLocationSheet(
  BuildContext context, {
  required String studentId,
  required String firstName,
  bool isFamily = false,
}) {
  return showModalBottomSheet<StudentHomeModel>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HomeLocationSheet(
      studentId: studentId,
      firstName: firstName,
      isFamily: isFamily,
    ),
  );
}

class _HomeLocationSheet extends ConsumerStatefulWidget {
  final String studentId;
  final String firstName;
  final bool isFamily;

  const _HomeLocationSheet({
    required this.studentId,
    required this.firstName,
    required this.isFamily,
  });

  @override
  ConsumerState<_HomeLocationSheet> createState() => _HomeLocationSheetState();
}

class _HomeLocationSheetState extends ConsumerState<_HomeLocationSheet> {
  final _link = TextEditingController();
  final _note = TextEditingController();
  LatLng? _point;
  bool _reading = false;
  bool _saving = false;
  bool _filled = false;

  @override
  void dispose() {
    _link.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _readLink() async {
    final text = _link.text.trim();
    if (text.isEmpty) return;

    // Links with the numbers inside are read here at once; short links
    // (maps.app.goo.gl) are followed by the server.
    final quick = coordinatesIn(text);
    if (quick != null && IraqMap.contains(quick)) {
      setState(() => _point = quick);
      return;
    }

    setState(() => _reading = true);
    try {
      final point = await ref.read(transportActionsProvider).readLocation(text);
      if (mounted) setState(() => _point = point);
    } on TransportException catch (e) {
      if (mounted) context.showMessage(e.message);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  /// Pastes the copied link and reads it.
  Future<void> _paste() async {
    final copied = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (copied == null || copied.trim().isEmpty) {
      if (mounted) context.showMessage(tr('Copy the location link first'));
      return;
    }
    _link.text = copied.trim();
    await _readLink();
  }

  Future<void> _save() async {
    final point = _point;
    if (point == null) return;

    setState(() => _saving = true);
    final home = StudentHomeModel(
      point: point,
      note: _note.text.trim(),
      sharedByFamily: widget.isFamily,
    );
    try {
      await ref
          .read(transportActionsProvider)
          .saveStudentHome(widget.studentId, home);
    } on TransportException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
      return;
    }
    if (mounted) Navigator.of(context).pop(home);
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(studentHomeProvider(widget.studentId)).valueOrNull;
    // Start from the home already on file, once.
    if (!_filled && saved != null) {
      _filled = true;
      _point ??= saved.point;
      _note.text = saved.note;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.isFamily
                ? tr('Our home for the school bus')
                : tr('Where is {0}\'s home?', [widget.firstName]),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.isFamily
                ? tr(
                    'The bus picks {0} up at the door. Stand at home and tap "I\'m here", or tap the map.',
                    [widget.firstName],
                  )
                : tr('The bus will pick {0} up at the door.', [
                    widget.firstName,
                  ]),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),

          if (saved != null && saved.sharedByFamily && !widget.isFamily)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                color: AppColors.success.withValues(alpha: 0.1),
                borderColor: Colors.transparent,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.home_outlined, color: AppColors.success),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        tr('The family shared their home{0}{1}', [
                          saved.updatedAt == null
                              ? ''
                              : ' ${DateFormatter.relativeDay(saved.updatedAt!).toLowerCase()}',
                          saved.note.isEmpty ? '' : ' · "${saved.note}"',
                        ]),
                        style: context.text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!widget.isFamily) ...[
            // The location link the family sent (WhatsApp, Google Maps...).
            TextField(
              controller: _link,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr('Paste location link'),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: _reading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: tr('Paste'),
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste),
                      ),
              ),
              // Pasted by hand: read it straight away.
              onChanged: (text) {
                if (text.contains('http') || coordinatesIn(text) != null) {
                  _readLink();
                }
              },
              onSubmitted: (_) => _readLink(),
            ),
            const SizedBox(height: AppSpacing.sm),
            PlaceSearchField(
              onPicked: (p) =>
                  setState(() => _point = LatLng(p.latitude, p.longitude)),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          LocationPicker(
            key: ValueKey(_point),
            point: _point,
            height: 240,
            onChanged: (p) => setState(() => _point = p),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: InputDecoration(
              labelText: tr('How to find the door (optional)'),
              hintText: tr('e.g. green gate next to the bakery'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _point == null || _saving ? null : _save,
            child: Text(
              _point == null ? tr('Choose the place first') : tr('Save home'),
            ),
          ),
        ],
      ),
    );
  }
}
