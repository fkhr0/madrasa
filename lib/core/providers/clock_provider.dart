import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ticks every 15 seconds so "smart" screens (current class, bus ETA,
/// "no more classes today"...) change by themselves as time passes.
final clockProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());

  final timer = Timer.periodic(
    const Duration(seconds: 15),
    (_) => controller.add(DateTime.now()),
  );

  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });

  return controller.stream;
});

/// The current time. Watch this instead of calling DateTime.now()
/// in widgets that should refresh on their own.
final nowProvider = Provider<DateTime>(
  (ref) => ref.watch(clockProvider).valueOrNull ?? DateTime.now(),
);
