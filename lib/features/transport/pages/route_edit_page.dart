import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/models/user_model.dart';
import '../../people/providers/people_provider.dart';
import '../models/bus_route_model.dart';
import '../providers/transport_provider.dart';
import '../repo/transport_repository.dart';
import '../../../core/l10n/language.dart';

/// Administrator: create a bus line or change its bus, driver and staff.
/// Stops and riders have their own pages.
class RouteEditPage extends ConsumerStatefulWidget {
  /// Null = a new line.
  final String? routeId;

  const RouteEditPage({super.key, this.routeId});

  @override
  ConsumerState<RouteEditPage> createState() => _RouteEditPageState();
}

class _RouteEditPageState extends ConsumerState<RouteEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _busNumber = TextEditingController();
  final _plate = TextEditingController();
  final _capacity = TextEditingController(text: '26');
  final _supervisor = TextEditingController();
  final _supervisorPhone = TextEditingController();
  String _driverId = '';

  BusRouteModel? _original;
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.routeId == null;

  @override
  void dispose() {
    for (final c in [
      _name,
      _busNumber,
      _plate,
      _capacity,
      _supervisor,
      _supervisorPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Fills the form once, when the line has loaded.
  void _fill(BusRouteModel route) {
    _original = route;
    _name.text = route.name;
    _busNumber.text = route.busNumber;
    _plate.text = route.plateNumber;
    _capacity.text = '${route.capacity}';
    _supervisor.text = route.supervisorName;
    _supervisorPhone.text = route.supervisorPhone;
    _driverId = route.driverId;
  }

  Future<void> _save(List<UserModel> drivers) async {
    if (!_formKey.currentState!.validate()) return;

    UserModel? driver;
    for (final d in drivers) {
      if (d.id == _driverId) driver = d;
    }

    final base =
        _original ??
        const BusRouteModel(
          id: '',
          name: '',
          busNumber: '',
          plateNumber: '',
          driverId: '',
          driverName: '',
          driverPhone: '',
          supervisorName: '',
          supervisorPhone: '',
          stops: [],
          capacity: 26,
        );

    setState(() => _saving = true);
    final BusRouteModel saved;
    try {
      saved = await ref
          .read(transportActionsProvider)
          .saveRoute(
            base.copyWith(
              name: _name.text.trim(),
              busNumber: _busNumber.text.trim(),
              plateNumber: _plate.text.trim(),
              capacity: int.parse(_capacity.text.trim()),
              driverId: driver?.id ?? '',
              driverName: driver?.name ?? '',
              driverPhone: driver?.phone ?? '',
              supervisorName: _supervisor.text.trim(),
              supervisorPhone: _supervisorPhone.text.trim(),
            ),
          );
    } on TransportException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
      return;
    }
    if (!mounted) return;

    if (_isNew) {
      // The natural next step for a new line: its stops.
      context.showMessage(tr('Line created. Now add its stops.'));
      context.pushReplacement(AppRoutes.routeStops(saved.id));
    } else {
      context.showMessage(tr('Saved'));
      context.pop();
    }
  }

  Future<void> _delete() async {
    final route = _original!;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete {0}?', [route.name])),
        content: Text(
          tr('{0} riders will have no bus. This can\'t be undone.', [
            route.studentCount,
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (sure != true) return;

    try {
      await ref.read(transportActionsProvider).deleteRoute(route.id);
      if (!mounted) return;
      context.showMessage(tr('{0} deleted', [route.name]));
      context.go(AppRoutes.transport);
    } on TransportException catch (e) {
      if (mounted) context.showMessage(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.routeId;
    final route = id == null ? null : ref.watch(busRouteProvider(id));
    final drivers =
        ref.watch(peopleByRoleProvider(UserRole.driver)).valueOrNull ?? [];
    final routes = ref.watch(busRoutesProvider).valueOrNull ?? [];

    final loaded = route?.valueOrNull;
    if (!_loaded && loaded != null) {
      _fill(loaded);
      _loaded = true;
    }
    if (id != null && !_loaded) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    /// "Drives bus 7" for drivers already on another line.
    String? busOf(UserModel driver) {
      for (final r in routes) {
        if (r.driverId == driver.id && r.id != id) {
          return tr('bus {0}', [r.busNumber]);
        }
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? tr('New bus line') : tr('Edit line')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: tr('Line name'),
                hintText: tr('e.g. Al-Mansour line'),
              ),
              validator: _required,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _busNumber,
                    decoration: InputDecoration(labelText: tr('Bus no.')),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: tr('Seats')),
                    validator: (v) {
                      final n = int.tryParse(v?.trim() ?? '');
                      if (n == null || n < 1 || n > 80) return tr('1 to 80');
                      final riders = _original?.studentCount ?? 0;
                      if (n < riders) return tr('Has {0} riders', [riders]);
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _plate,
              decoration: InputDecoration(
                labelText: tr('Plate number'),
                hintText: tr('e.g. Baghdad 41582'),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('Driver')),
            DropdownButtonFormField<String>(
              // The app's card look, not the default grey strip.
              dropdownColor: context.palette.card,

              borderRadius: BorderRadius.circular(AppRadius.md),

              menuMaxHeight: 360,
              initialValue: _driverId,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Driver')),
              items: [
                DropdownMenuItem(value: '', child: Text(tr('No driver yet'))),
                for (final d in drivers)
                  DropdownMenuItem(
                    value: d.id,
                    child: Text(
                      busOf(d) == null
                          ? d.name
                          : tr('{0} (now on {1})', [d.name, busOf(d)]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _driverId = v ?? ''),
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                tr(
                  'A driver drives one bus. Choosing someone from another line moves them here. Add drivers in People.',
                ),
                style: context.text.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('Supervisor on the bus')),
            TextFormField(
              controller: _supervisor,
              decoration: InputDecoration(labelText: tr('Name')),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _supervisorPhone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: tr('Phone'),
                hintText: tr('+964 7xx xxx xxxx'),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: _saving ? null : () => _save(drivers),
              child: Text(_isNew ? tr('Create line') : tr('Save changes')),
            ),
            if (!_isNew) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(tr('Delete line')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? tr('Required') : null;
}
