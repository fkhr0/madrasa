class AppConfig {
  AppConfig._();

  static const apiUrl = String.fromEnvironment('API_URL');

  static bool get useApi => apiUrl.isNotEmpty;

  static bool get showDemoAccounts => !useApi;

  static bool get asksForServer => apiUrl == 'ask';

  static String chosenServer = '';

  static String get apiBaseUrl => switch (apiUrl) {
    'origin' => Uri.base.origin,
    'ask' => chosenServer,
    _ => apiUrl,
  };
}
