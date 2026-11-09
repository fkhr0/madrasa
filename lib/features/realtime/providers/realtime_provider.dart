import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/network/realtime_client.dart';
import '../../auth/providers/auth_provider.dart';

/// The live connection while someone is signed in to the server; null in
/// mock mode or when signed out. A new sign-in gets a new connection.
final realtimeClientProvider = Provider<RealtimeClient?>((ref) {
  final userId = ref.watch(authProvider.select((user) => user?.id));
  if (!AppConfig.useApi || userId == null) return null;

  final client = RealtimeClient(ref.watch(apiClientProvider))..connect();
  ref.onDispose(client.close);
  return client;
});

/// Every event the server pushes (none in mock mode).
final realtimeEventsProvider = StreamProvider<RealtimeEvent>(
  (ref) => ref.watch(realtimeClientProvider)?.events ?? const Stream.empty(),
);
