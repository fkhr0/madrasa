import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../constants/app_radius.dart';
import '../constants/app_spacing.dart';
import '../location/device_location.dart';
import '../providers/map_provider.dart';
import '../utils/location_link.dart';
import '../utils/context_extensions.dart';
import '../l10n/language.dart';

/// A map to choose one place: tap to put the pin, or use this phone's
/// location. Used for the school gate and for bus stops.
class LocationPicker extends ConsumerStatefulWidget {
  final LatLng? point;
  final ValueChanged<LatLng> onChanged;

  /// Other places to show for context (e.g. the line's other stops).
  final List<LatLng> nearby;
  final double height;

  const LocationPicker({
    super.key,
    required this.point,
    required this.onChanged,
    this.nearby = const [],
    this.height = 220,
  });

  /// Where the map opens when nothing is chosen yet.
  static const baghdad = LatLng(33.3152, 44.3661);

  @override
  ConsumerState<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<LocationPicker> {
  final _map = MapController();
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final here = await DeviceLocation.currentFix();
      widget.onChanged(here.point);
      _map.move(here.point, 16);
      // Indoors the phone may only know the area: say so, so the pin gets
      // moved onto the right house.
      if (here.accuracy > 50 && mounted) {
        context.showMessage(
          tr('This may be up to {0} m off. Move the pin to the exact place.', [
            here.accuracy.round(),
          ]),
        );
      }
    } on LocationException catch (e) {
      if (mounted) context.showMessage(e.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final point = widget.point;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            height: widget.height,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: point ?? LocationPicker.baghdad,
                initialZoom: point == null ? 11 : 15,
                // The map of Iraq only.
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    const LatLng(IraqMap.south, IraqMap.west),
                    const LatLng(IraqMap.north, IraqMap.east),
                  ),
                ),
                minZoom: 6,
                backgroundColor: palette.cardMuted,
                onTap: (_, p) => widget.onChanged(p),
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
                MarkerLayer(
                  markers: [
                    for (final p in widget.nearby)
                      Marker(
                        point: p,
                        width: 12,
                        height: 12,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.card,
                            border: Border.all(
                              color: palette.textSecondary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    if (point != null)
                      Marker(
                        point: point,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: Icon(
                          Icons.location_on,
                          size: 40,
                          color: palette.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                point == null
                    ? tr('Not set yet')
                    : '${point.latitude.toStringAsFixed(5)}, '
                          '${point.longitude.toStringAsFixed(5)}',
                style: context.text.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _locating ? null : _useMyLocation,
              icon: const Icon(Icons.my_location, size: 18),
              label: Text(tr('I\'m here')),
            ),
          ],
        ),
      ],
    );
  }
}
