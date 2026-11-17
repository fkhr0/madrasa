import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'api_client.dart';
import 'response_cache.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    cache: DeviceResponseCache(),
  );
  client.onSavedAnswersOutdated = () =>
      ref.read(apiDataVersionProvider.notifier).update((v) => v + 1);
  return client;
});

final apiDataVersionProvider = StateProvider<int>((ref) => 0);

ApiClient watchApi(Ref ref) {
  ref.watch(apiDataVersionProvider);
  return ref.watch(apiClientProvider);
}
