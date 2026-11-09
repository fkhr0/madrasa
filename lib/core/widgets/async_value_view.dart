import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_strings.dart';
import 'empty_state.dart';

/// Shows a loader, an error with a retry button, or [data], so every
/// screen handles loading the same way. Works the same with mock data
/// today and with the real server later.
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      // Reloading in the background (e.g. the 15-second check): keep
      // showing what is there, and keep it if that check fails.
      skipLoadingOnReload: true,
      skipError: value.hasValue,
      data: data,
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: AppStrings.genericError,
        action: onRetry == null
            ? null
            : OutlinedButton(onPressed: onRetry, child: Text(AppStrings.retry)),
      ),
    );
  }
}
