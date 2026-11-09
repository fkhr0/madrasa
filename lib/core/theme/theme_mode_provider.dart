import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Follows the phone until the user picks Light or Dark in Settings.
/// (Saved to the device in a later stage.)
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
