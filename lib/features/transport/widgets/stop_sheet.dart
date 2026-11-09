import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../models/bus_stop_model.dart';
import '../../../core/l10n/language.dart';

/// What the administrator did in the stop sheet.
sealed class StopSheetResult {
  const StopSheetResult();
}

class StopSaved extends StopSheetResult {
  final BusStopModel stop;

  const StopSaved(this.stop);
}

class StopDeleted extends StopSheetResult {
  const StopDeleted();
}

/// Name, landmark and planned times of one stop.
/// [ridersHere] warns before deleting a stop that has students.
Future<StopSheetResult?> showStopSheet(
  BuildContext context, {
  required BusStopModel stop,
  required bool isNew,
  int ridersHere = 0,
}) {
  return showModalBottomSheet<StopSheetResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _StopSheet(stop: stop, isNew: isNew, ridersHere: ridersHere),
  );
}

/// "07:22" for 442 minutes after midnight.
String minuteText(int minuteOfDay) =>
    DateFormatter.time(DateTime(2000).add(Duration(minutes: minuteOfDay)));

class _StopSheet extends StatefulWidget {
  final BusStopModel stop;
  final bool isNew;
  final int ridersHere;

  const _StopSheet({
    required this.stop,
    required this.isNew,
    required this.ridersHere,
  });

  @override
  State<_StopSheet> createState() => _StopSheetState();
}

class _StopSheetState extends State<_StopSheet> {
  late final _name = TextEditingController(text: widget.stop.name);
  late final _landmark = TextEditingController(text: widget.stop.landmark);
  late int _morning = widget.stop.morningMinute;
  late int _afternoon = widget.stop.afternoonMinute;
  late LatLng _point = LatLng(widget.stop.latitude, widget.stop.longitude);

  @override
  void dispose() {
    _name.dispose();
    _landmark.dispose();
    super.dispose();
  }

  Future<int?> _pickTime(int minuteOfDay) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60),
    );

    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      context.showMessage(tr('Give the stop a name'));
      return;
    }

    Navigator.pop(
      context,
      StopSaved(
        widget.stop.copyWith(
          name: _name.text.trim(),
          landmark: _landmark.text.trim(),
          latitude: _point.latitude,
          longitude: _point.longitude,
          morningMinute: _morning,
          afternoonMinute: _afternoon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSchool = widget.stop.isSchool;

    // Scrolls on small phones, where the map and the keyboard don't fit.
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
            widget.isNew ? tr('New stop') : tr('Edit stop'),
            style: context.text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            enabled: !isSchool,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('Stop name'),
              hintText: tr('e.g. Al-Yarmouk'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _landmark,
            decoration: InputDecoration(
              labelText: tr('Landmark'),
              hintText: tr('Something easy to find, e.g. the hospital gate'),
            ),
          ),
          if (!isSchool) ...[
            const SizedBox(height: AppSpacing.md),
            // Tap to move the stop, or stand there and tap "I'm here".
            LocationPicker(
              point: _point,
              height: 160,
              onChanged: (p) => setState(() => _point = p),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _TimeButton(
                  icon: Icons.wb_sunny_outlined,
                  label: isSchool ? tr('Arrives') : tr('Morning'),
                  minute: _morning,
                  onTap: () async {
                    final m = await _pickTime(_morning);
                    if (m != null) setState(() => _morning = m);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _TimeButton(
                  icon: Icons.nights_stay_outlined,
                  label: isSchool ? tr('Leaves') : tr('Afternoon'),
                  minute: _afternoon,
                  onTap: () async {
                    final m = await _pickTime(_afternoon);
                    if (m != null) setState(() => _afternoon = m);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: _save,
            child: Text(widget.isNew ? tr('Add stop') : tr('Done')),
          ),
          if (!widget.isNew && !isSchool) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () async {
                final sure = await confirmDelete(
                  context,
                  title: tr('Remove {0}?', [widget.stop.name]),
                  message: widget.ridersHere == 0
                      ? tr('No students get on here.')
                      : tr(
                          '{0} students get on here. They will come off the line until you give them a new stop.',
                          [widget.ridersHere],
                        ),
                  action: tr('Remove'),
                );
                if (sure && context.mounted) {
                  Navigator.pop(context, const StopDeleted());
                }
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(
                widget.ridersHere == 0
                    ? tr('Remove stop')
                    : tr('Remove stop ({0} riders come off the line)', [
                        widget.ridersHere,
                      ]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int minute;
  final VoidCallback onTap;

  const _TimeButton({
    required this.icon,
    required this.label,
    required this.minute,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Text(label, style: context.text.labelMedium),
            ],
          ),
          Text(minuteText(minute), style: context.text.titleLarge),
        ],
      ),
    );
  }
}
