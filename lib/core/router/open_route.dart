import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';

extension OpenRoute on BuildContext {
  void openRoute(String location) {
    if (AppRoutes.isInTabs(location)) {
      go(location);
    } else {
      push(location);
    }
  }
}
