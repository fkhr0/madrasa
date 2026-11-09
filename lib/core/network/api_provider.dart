import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'response_cache.dart';

/// One client for the whole app, so every repository shares the tokens.
/// Only used when [AppConfig.useApi] is true.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    cache: DeviceResponseCache(),
  );
  // Saved answers shown at start were out of date: every screen loads again.
  client.onSavedAnswersOutdated = () =>
      ref.read(apiDataVersionProvider.notifier).update((v) => v + 1);
  return client;
});

/// Goes up when the server has newer data than what the screens show.
final apiDataVersionProvider = StateProvider<int>((ref) => 0);

/// The client for a repository provider: the repository (and every screen
/// using it) is made again when the data version goes up.
ApiClient watchApi(Ref ref) {
  ref.watch(apiDataVersionProvider);
  return ref.watch(apiClientProvider);
}
