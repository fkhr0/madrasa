import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/async_value_view.dart';
import '../models/institution_model.dart';
import '../providers/institution_provider.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/l10n/language.dart';

/// Administrator: the whole school's settings, name, contact details,
/// the school gate on the map (every bus line ends there) and the study week.
class SchoolSettingsPage extends ConsumerWidget {
  const SchoolSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final institution = ref.watch(institutionProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('School settings'))),
      body: AsyncValueView(
        value: institution,
        onRetry: () => ref.invalidate(institutionProvider),
        data: (institution) => _Form(institution: institution),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  final InstitutionModel institution;

  const _Form({required this.institution});

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(text: widget.institution.name);
  late final _city = TextEditingController(text: widget.institution.city);
  late final _address = TextEditingController(text: widget.institution.address);
  late final _phone = TextEditingController(text: widget.institution.phone);
  late final _email = TextEditingController(text: widget.institution.email);
  late final _whatsapp = TextEditingController(
    text: widget.institution.whatsapp,
  );
  late LatLng? _location = widget.institution.hasLocation
      ? LatLng(widget.institution.latitude!, widget.institution.longitude!)
      : null;

  /// Null until the administrator changes the study week.
  List<int>? _workingDays;
  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 3) {
      context.showMessage(tr('Write the school\'s name'));
      return;
    }

    setState(() => _isSaving = true);
    final actions = ref.read(institutionActionsProvider);
    try {
      await actions.updateInstitution(
        InstitutionModel(
          id: widget.institution.id,
          name: _name.text.trim(),
          city: _city.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          whatsapp: _whatsapp.text.trim(),
          latitude: _location?.latitude,
          longitude: _location?.longitude,
        ),
      );
      if (_workingDays case final days?) {
        await actions.updateWorkingDays(days);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      context.showMessage(e.message);
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    context.showMessage(tr('Settings saved'));
  }

  void _toggleDay(List<int> current, int weekday) {
    final days = [...current];
    days.contains(weekday) ? days.remove(weekday) : days.add(weekday);
    if (days.isEmpty) {
      context.showMessage(tr('Keep at least one study day'));
      return;
    }
    setState(() => _workingDays = days);
  }

  @override
  Widget build(BuildContext context) {
    final year = ref.watch(academicYearProvider).valueOrNull;
    final workingDays = _workingDays ?? year?.workingDays;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.page),
      children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('School name'),
            prefixIcon: Icon(Icons.apartment_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _city,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: tr('City'),
            prefixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _address,
          decoration: InputDecoration(
            labelText: tr('Address'),
            hintText: tr('e.g. Al-Mansour, 14th of Ramadan street'),
            prefixIcon: Icon(Icons.signpost_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: tr('School phone'),
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: tr('WhatsApp (optional)'),
            hintText: tr('+964 7XX XXX XXXX'),
            prefixIcon: const Icon(Icons.chat_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: tr('School email (optional)'),
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('Families see these on the Help page to reach the school.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.xl),

        Text(tr('School gate on the map'), style: context.text.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tr('Every bus line ends here. Tap the map to move it.'),
          style: context.text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        LocationPicker(
          point: _location,
          onChanged: (p) => setState(() => _location = p),
        ),
        const SizedBox(height: AppSpacing.xl),

        if (workingDays != null) ...[
          Text(tr('Study week'), style: context.text.labelMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              // Sunday first, as the Iraqi week starts (1 Nov 2026 is a Sunday).
              for (var i = 0; i < 7; i++)
                FilterChip(
                  label: Text(
                    DateFormatter.weekdayShort(DateTime(2026, 11, 1 + i)),
                  ),
                  selected: workingDays.contains(
                    DateTime(2026, 11, 1 + i).weekday,
                  ),
                  onSelected: (_) => _toggleDay(
                    workingDays,
                    DateTime(2026, 11, 1 + i).weekday,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr(
              'Days with classes in {0}. Buses, the schedule and the calendar follow it.',
              [year!.name],
            ),
            style: context.text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('Save')),
        ),
      ],
    );
  }
}
