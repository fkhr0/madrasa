import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class ServerAddress {
  ServerAddress._();

  static const _key = 'server.address';

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
