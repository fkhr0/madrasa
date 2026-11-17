import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/providers/map_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../models/bus_stop_model.dart';
import '../models/road_path_model.dart';
import '../models/trip_model.dart';
import '../../../core/l10n/language.dart';

class BusMap extends ConsumerStatefulWidget {
  final List<BusStopModel> stops;
  final TripModel? trip;
  final String? myStopId;
  final double height;

  final RoadPathModel? road;

  final ValueChanged<LatLng>? onTap;

  const BusMap({
    super.key,
    required this.stops,
    this.trip,
    this.myStopId,
    this.height = 240,
    this.road,
    this.onTap,
  });

  @override
  ConsumerState<BusMap> createState() => _BusMapState();
}

class _BusMapState extends ConsumerState<BusMap> {
  final _map = MapController();
  bool _ready = false;
  bool _following = true;

  static LatLng _point(BusStopModel s) => LatLng(s.latitude, s.longitude);

  static LatLngBounds _grow(LatLngBounds bounds) => LatLngBounds(
    LatLng(bounds.south - 0.015, bounds.west - 0.015),
    LatLng(bounds.north + 0.015, bounds.east + 0.015),
  );

  static const _baghdad = [LatLng(33.26, 44.28), LatLng(33.36, 44.44)];

  LatLng? _busOf(TripModel? trip) {
    if (trip == null ||
        !trip.isLive ||
        !trip.hasPosition ||
        trip.phase == TripPhase.noTripToday) {
      return null;
    }
    return LatLng(trip.latitude!, trip.longitude!);
  }

  @override
  void didUpdateWidget(BusMap old) {
    super.didUpdateWidget(old);
    final bus = _busOf(widget.trip);
    if (bus == null || !_following || !_ready) return;
    if (bus == _busOf(old.trip)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _map.move(bus, _map.camera.zoom);
    });
  }

  void _follow(LatLng bus) {
    setState(() => _following = true);
    final zoom = _map.camera.zoom;
    _map.move(bus, zoom < 14 ? 14 : zoom);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final points = widget.stops.map(_point).toList();
    final trip = widget.trip;
    final line = (trip?.road ?? widget.road)?.points ?? points;
    final showBus =
        trip != null && trip.hasPosition && trip.phase != TripPhase.noTripToday;
    final bus = _busOf(trip);
    final bounds = LatLngBounds.fromPoints(
      line.length > 1 ? line : [...points, ..._baghdad],
    );
    final area = bus == null
        ? bounds
        : LatLngBounds.fromPoints([bounds.southWest, bounds.northEast, bus]);
    final editing = widget.onTap != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: area.center,
                initialZoom: 12,
                initialCameraFit: CameraFit.bounds(
                  bounds: area,
                  padding: const EdgeInsets.all(36),
                ),
                cameraConstraint: editing
                    ? const CameraConstraint.unconstrained()
                    : CameraConstraint.contain(bounds: _grow(area)),
                minZoom: editing ? null : 6,
                backgroundColor: palette.cardMuted,
                onTap: editing ? (_, point) => widget.onTap!(point) : null,
                onMapReady: () {
                  _ready = true;
                  _map.fitCamera(
                    CameraFit.bounds(
                      bounds: area,
                      padding: const EdgeInsets.all(36),
                    ),
                  );
                },
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _following && bus != null) {
                    setState(() => _following = false);
                  }
                },
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                if (ref.watch(mapTilesEnabledProvider))
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'iq.madrasa.school',
                  ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: line,
                      strokeWidth: 5,
                      color: palette.primary.withValues(alpha: 0.75),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final stop in widget.stops)
                      Marker(
                        point: _point(stop),
                        width: stop.id == widget.myStopId ? 26 : 16,
                        height: stop.id == widget.myStopId ? 26 : 16,
                        child: _StopDot(
                          isMine: stop.id == widget.myStopId,
                          isSchool: stop.isSchool,
                        ),
                      ),
                    if (showBus)
                      Marker(
                        point: LatLng(trip.latitude!, trip.longitude!),
                        width: 40,
                        height: 40,
                        child: _BusMarker(isLive: trip.isLive),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: palette.card.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      tr('© OpenStreetMap'),
                      style: context.text.labelSmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (bus != null && !_following)
              Positioned(
                top: 8,
                right: 8,
                child: FilledButton.tonalIcon(
                  onPressed: () => _follow(bus),
                  icon: const Icon(Icons.directions_bus, size: 18),
                  label: Text(tr('Follow the bus')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StopDot extends StatelessWidget {
  final bool isMine;
  final bool isSchool;

  const _StopDot({required this.isMine, required this.isSchool});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMine || isSchool ? palette.primary : palette.card,
        border: Border.all(color: palette.primary, width: 3),
      ),
      child: isSchool
          ? Icon(Icons.school, size: 10, color: palette.onPrimary)
          : null,
    );
  }
}

class _BusMarker extends StatelessWidget {
  final bool isLive;

  const _BusMarker({required this.isLive});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.primary,
        border: Border.all(
          color: isLive ? AppColors.success : Colors.white,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Icon(Icons.directions_bus, size: 20, color: palette.onPrimary),
    );
  }
}
