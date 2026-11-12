import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/location/device_location.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../transport/providers/transport_provider.dart';
import '../../transport/repo/transport_repository.dart';
import '../../../core/l10n/language.dart';

/// While a trip runs, sends this phone's GPS position to the server so
/// families see the bus move. Shows one line saying whether it works.
class GpsReporter extends ConsumerStatefulWidget {
  final String routeId;

  const GpsReporter({super.key, required this.routeId});

  /// At most one point this often (the phone may report more).
  static const sendEvery = Duration(seconds: 5);

  /// A reading older than this is not repeated: families would see a bus that
  /// looks live but stopped moving.
  static const repeatFor = kIsWeb
      ? Duration(minutes: 2)
      : Duration(seconds: 25);

  /// Not moved more than [stillWithin] metres for [stillAfter]: standing at
  /// a stop or a light (said plainly, not as a problem).
  static const stillAfter = Duration(minutes: 1);
  static const stillWithin = 25.0;

  @override
  ConsumerState<GpsReporter> createState() => _GpsReporterState();
}

class _GpsReporterState extends ConsumerState<GpsReporter>
    with WidgetsBindingObserver {
  StreamSubscription<GpsFix>? _subscription;
  Timer? _keepAlive;
  GpsFix? _last;
  DateTime? _lastReadAt;
  DateTime? _lastSent;

  /// Where and when the bus last really moved.
  GpsFix? _movedFrom;
  DateTime? _movedAt;
  String? _problem;

  /// The phone setting that fixes [_problem], if one does.
  LocationFix _fix = LocationFix.none;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  /// Back from the phone settings: try again by itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _fix != LocationFix.none) {
      _start();
    }
  }

  Future<void> _start() async {
    _subscription?.cancel();
    _keepAlive?.cancel();
    setState(() {
      _problem = null;
      _fix = LocationFix.none;
    });

    // One reading straight away: it also makes the browser ask for
    // permission, and shows a problem at once instead of never.
    try {
      _read(await DeviceLocation.currentFix());
    } on LocationException catch (e) {
      if (mounted) {
        setState(() {
          _problem = e.message;
          _fix = e.fix;
        });
      }
      return;
    }
    if (!mounted) return;

    // keepRunning: the Android app keeps sending with the screen off.
    // distanceFilter 0: a reading every few seconds, moving or not.
    _subscription = DeviceLocation.watch(distanceFilter: 0, keepRunning: true)
        .listen(
          _read,
          onError: (Object e) {
            final problem = DeviceLocation.explain(e);
            setState(() {
              _problem = problem.message;
              _fix = problem.fix;
            });
          },
        );
    // A bus waiting at a light doesn't move, so the phone reports nothing
    // new: repeat the last point so families still see it live, but only
    // a recent one.
    _keepAlive = Timer.periodic(const Duration(seconds: 10), (_) {
      final readAt = _lastReadAt;
      if (_last == null || readAt == null) return;
      if (DateTime.now().difference(readAt) < GpsReporter.repeatFor) {
        _send(_last!, force: true);
      } else if (mounted) {
        setState(
          () => _problem = tr(
            'The phone has lost the GPS signal. Families see where the bus '
            'was last. Keep the app open with location on; it comes back '
            'by itself.',
          ),
        );
      }
    });
  }

  /// A new reading from the phone.
  void _read(GpsFix fix) {
    final now = DateTime.now();
    _lastReadAt = now;
    final from = _movedFrom;
    if (from == null ||
        const Distance().as(LengthUnit.Meter, from.point, fix.point) >
            GpsReporter.stillWithin) {
      _movedFrom = fix;
      _movedAt = now;
    }
    _send(fix, force: _last == null);
  }

  /// Standing still for a while (a stop, a light, traffic).
  bool get _standing {
    final movedAt = _movedAt;
    return movedAt != null &&
        DateTime.now().difference(movedAt) > GpsReporter.stillAfter;
  }

  Future<void> _send(GpsFix fix, {bool force = false}) async {
    _last = fix;
    final now = DateTime.now();
    if (!force &&
        _lastSent != null &&
        now.difference(_lastSent!) < GpsReporter.sendEvery) {
      return;
    }
    _lastSent = now;

    try {
      await ref
          .read(transportActionsProvider)
          .sendLocation(
            widget.routeId,
            fix.point.latitude,
            fix.point.longitude,
            accuracy: fix.accuracy,
          );
      if (mounted) {
        setState(() {
          _sending = true;
          _problem = null;
        });
      }
    } on TransportException catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _keepAlive?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    final color = problem != null
        ? AppColors.warning
        : _sending
        ? AppColors.success
        : context.palette.textMuted;

    return Row(
      children: [
        Icon(
          problem != null ? Icons.location_off_outlined : Icons.gps_fixed,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            problem ??
                (!_sending
                    ? tr('Finding your location…')
                    : _standing
                    ? tr('Standing still · families see the bus here')
                    : tr('GPS on · families see the bus live')),
            style: context.text.bodySmall?.copyWith(color: color),
          ),
        ),
        if (problem != null)
          switch (_fix) {
            LocationFix.turnOn => TextButton(
              onPressed: () => DeviceLocation.openSettingsFor(_fix),
              child: Text(tr('Turn on location')),
            ),
            LocationFix.allow => TextButton(
              onPressed: () => DeviceLocation.openSettingsFor(_fix),
              child: Text(tr('Open settings')),
            ),
            LocationFix.none => TextButton(
              onPressed: _start,
              child: Text(tr('Try again')),
            ),
          },
      ],
    );
  }
}
