/// Build settings, passed with --dart-define.
class AppConfig {
  AppConfig._();

  static const apiUrl = String.fromEnvironment('API_URL');

  /// True when the app talks to the server instead of the mock data.
  static bool get useApi => apiUrl.isNotEmpty;

  /// The demo accounts list on the sign-in page: mock mode only. Online the
  /// demo has no password ("Try the demo" signs in).
  static bool get showDemoAccounts => !useApi;

  /// Test builds: the sign-in page asks for the server's address.
  static bool get asksForServer => apiUrl == 'ask';

  /// The address typed on the sign-in page (server_address.dart).
  static String chosenServer = '';

  /// The server's address. "origin" = where this web page came from.
  static String get apiBaseUrl => switch (apiUrl) {
    'origin' => Uri.base.origin,
    'ask' => chosenServer,
    _ => apiUrl,
  };
}
