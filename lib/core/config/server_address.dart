import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// Test builds (API_URL=ask) let the sign-in page set the server's address,
/// because a Cloudflare test tunnel gets a new one each time it starts.
class ServerAddress {
  ServerAddress._();

  static const _key = 'server.address';

  /// Called in main(), before anything talks to the server.
  static Future<void> load() async {
    if (!AppConfig.asksForServer) return;
    final prefs = await SharedPreferences.getInstance();
    AppConfig.chosenServer = prefs.getString(_key) ?? '';
  }

  static Future<void> save(String address) async {
    AppConfig.chosenServer = address;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, address);
  }

  /// "  https://x.trycloudflare.com/ " -> "https://x.trycloudflare.com",
  /// or null when it isn't a web address.
  static String? clean(String text) {
    final address = text.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(address);
    final ok =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return ok ? address : null;
  }
}
