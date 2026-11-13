import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../logic/stop_planning.dart';
import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../providers/transport_provider.dart';
import '../repo/transport_repository.dart';
import '../models/trip_model.dart';
import '../widgets/bus_map.dart';
import '../widgets/place_search_field.dart';
import '../widgets/stop_sheet.dart';
import '../../../core/l10n/language.dart';

/// Administrator: the stops of a line on a map.
class RouteStopsPage extends ConsumerStatefulWidget {
  final String routeId;

  const RouteStopsPage({super.key, required this.routeId});

  @override
  ConsumerState<RouteStopsPage> createState() => _RouteStopsPageState();
}

class _RouteStopsPageState extends ConsumerState<RouteStopsPage> {
  BusRouteModel? _route;

  /// Edited copy, school last. Saved with the button.
  List<BusStopModel> _stops = [];
  bool _changed = false;
  bool _saving = false;
  int _newCount = 0;

  void _set(List<BusStopModel> stops) => setState(() {
    _stops = stops;
    _changed = true;
  });

  Future<void> _addAt(LatLng point, {String name = ''}) async {
    final index = bestInsertIndex(_stops, point.latitude, point.longitude);
    final (morning, afternoon) = suggestedTimes(_stops, index);

    final result = await showStopSheet(
      context,
      isNew: true,
      stop: BusStopModel(
        id:
            '${BusStopModel.newIdPrefix}${DateTime.now().millisecondsSinceEpoch}-'
            '${_newCount++}',
        name: name,
        landmark: '',
        latitude: point.latitude,
        longitude: point.longitude,
        morningMinute: morning,
        afternoonMinute: afternoon,
      ),
    );
    if (result is StopSaved) _set([..._stops]..insert(index, result.stop));
  }

  Future<void> _edit(int index, int ridersHere) async {
    final result = await showStopSheet(
      context,
      stop: _stops[index],
      isNew: false,
      ridersHere: ridersHere,
    );

    switch (result) {
      case StopSaved(:final stop):
        _set([..._stops]..[index] = stop);
      case StopDeleted():
        _set([..._stops]..removeAt(index));
      case null:
        break;
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    final stops = [..._stops];
    final school = stops.removeLast();
    stops.insert(newIndex, stops.removeAt(oldIndex));
    // New order, new times: keep the timetable consistent.
    _set(evenTimes([...stops, school]));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final BusRouteModel saved;
    try {
      saved = await ref
          .read(transportActionsProvider)
          .saveRoute(_route!.copyWith(stops: _stops));
    } on TransportException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      context.showMessage(e.message);
      return;
    }
    if (!mounted) return;
    context.showMessage(tr('Stops saved and drawn on the streets'));
    // Stay: the admin sees the new road and can use its driving times.
    // The server's copy has the new stop IDs and the road.
    setState(() {
      _route = saved;
      _stops = [...saved.stops];
      _changed = false;
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(busRouteProvider(widget.routeId)).valueOrNull;
    final riders =
        ref.watch(routeStudentsProvider(widget.routeId)).valueOrNull ?? [];

    if (_route == null && route != null) {
      _route = route;
      _stops = [...route.stops];
    }
    if (_route == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final problem = timetableProblem(_stops);
    final pickUps = _stops.length - 1;

    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(tr('Leave without saving?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(tr('Stay')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(tr('Leave')),
              ),
            ],
          ),
        );
        // Navigator.pop is not stopped by PopScope (only back gestures are).
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Stops · {0}', [_route!.name])),
          actions: [
            TextButton(
              onPressed: !_changed || problem != null || _saving ? null : _save,
              child: Text(tr('Save')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            // 1. Put the stops where students get on and off...
            PlaceSearchField(
              onPicked: (p) =>
                  _addAt(LatLng(p.latitude, p.longitude), name: p.name),
            ),
            const SizedBox(height: AppSpacing.sm),
            BusMap(
              stops: _stops,
              height: 260,
              onTap: _addAt,
              // The saved road; edited stops wait for Save to be redrawn.
              road: _changed ? null : _route!.roadFor(TripDirection.toSchool),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr(
                'Search a place or tap the map to add a stop. It is placed where it adds the least driving, with suggested times.',
              ),
              style: context.text.bodySmall,
            ),
            // 2. ...then the line is drawn on the streets.
            const SizedBox(height: AppSpacing.sm),
            _RoadSummary(
              route: _route!,
              changed: _changed,
              onUseRoadTimes: () => _set(
                timesFromRoads(
                  _stops,
                  _route!.roadToSchool!,
                  _route!.roadToHome,
                ),
              ),
            ),
            if (problem != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderColor: Colors.transparent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(problem, style: context.text.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      onPressed: () => _set(evenTimes(_stops)),
                      icon: const Icon(Icons.auto_fix_high, size: 18),
                      label: Text(tr('Fix times for me')),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (pickUps == 0)
              EmptyState(
                icon: Icons.add_location_alt_outlined,
                title: tr('No stops yet'),
                message: tr(
                  'Tap the map where the bus should pick students up.',
                ),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorderItem: _reorder,
                children: [
                  for (var i = 0; i < pickUps; i++)
                    _StopTile(
                      key: ValueKey(_stops[i].id),
                      number: i + 1,
                      stop: _stops[i],
                      riders: riders
                          .where((r) => r.stopId == _stops[i].id)
                          .length,
                      dragIndex: i,
                      onTap: () => _edit(
                        i,
                        riders.where((r) => r.stopId == _stops[i].id).length,
                      ),
                    ),
                ],
              ),
            _StopTile(
              number: null,
              stop: _stops.last,
              riders: 0,
              onTap: () => _edit(_stops.length - 1, 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTile extends StatelessWidget {
  /// Null for the school.
  final int? number;
  final BusStopModel stop;
  final int riders;
  final int? dragIndex;
  final VoidCallback onTap;

  const _StopTile({
    super.key,
    required this.number,
    required this.stop,
    required this.riders,
    required this.onTap,
    this.dragIndex,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.primarySoft,
              child: number == null
                  ? Icon(Icons.school, size: 16, color: palette.primary)
                  : Text(
                      '$number',
                      style: context.text.labelLarge?.copyWith(
                        color: palette.primary,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.name.isEmpty ? tr('Unnamed stop') : stop.name,
                    style: context.text.titleSmall,
                  ),
                  Text(
                    '${minuteText(stop.morningMinute)} · '
                    '${minuteText(stop.afternoonMinute)}'
                    '${riders > 0 ? ' · $riders riders' : ''}',
                    style: context.text.bodySmall,
                  ),
                ],
              ),
            ),
            if (dragIndex != null)
              ReorderableDragStartListener(
                index: dragIndex!,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.sm),
                  child: Icon(Icons.drag_indicator),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whether the line is drawn on the streets, how long it takes, and a
/// button to plan the stop times from the real driving times.
class _RoadSummary extends StatelessWidget {
  final BusRouteModel route;
  final bool changed;
  final VoidCallback onUseRoadTimes;

  const _RoadSummary({
    required this.route,
    required this.changed,
    required this.onUseRoadTimes,
  });

  @override
  Widget build(BuildContext context) {
    final road = route.roadFor(TripDirection.toSchool);

    if (changed) {
      return _line(
        context,
        Icons.edit_road_outlined,
        tr('Save to draw the line on the streets.'),
      );
    }
    if (route.pickUpStops.isEmpty) return const SizedBox.shrink();
    if (road == null) {
      return _line(
        context,
        Icons.timeline,
        tr(
          'Drawn as straight lines: the road service could not be reached. Save again later to draw it on the streets.',
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, size: 20, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              tr('On the streets: {0} to school', [road.summary]),
              style: context.text.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onUseRoadTimes,
            child: Text(tr('Use driving times')),
          ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: context.palette.textMuted),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(text, style: context.text.bodySmall)),
    ],
  );
}
