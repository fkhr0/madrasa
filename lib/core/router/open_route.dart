import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

extension OpenRoute on BuildContext {
  /// Opens a link that came from data (a notification, a reminder):
  /// switches tab for tab pages, pushes everything else.
  void openRoute(String location) {
    if (AppRoutes.isInTabs(location)) {
      go(location);
    } else {
      push(location);
    }
  }
}
