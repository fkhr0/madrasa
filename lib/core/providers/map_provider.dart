import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether maps download OpenStreetMap tiles. Tests override this to
/// false (no internet there); the map then shows only its own drawings.
final mapTilesEnabledProvider = Provider<bool>((ref) => true);
