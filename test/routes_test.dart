import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/router/app_routes.dart';

void main() {
  test('tab pages are opened by switching tab, others are pushed', () {
    expect(AppRoutes.isInTabs(AppRoutes.home), isTrue);
    expect(AppRoutes.isInTabs(AppRoutes.work), isTrue);
    expect(AppRoutes.isInTabs(AppRoutes.chat('t3')), isTrue);

    expect(AppRoutes.isInTabs(AppRoutes.bus), isFalse);
    expect(AppRoutes.isInTabs(AppRoutes.tasks), isFalse);
    expect(AppRoutes.isInTabs(AppRoutes.assignmentDetails('a1')), isFalse);
    // "/homework" must not count as the "/home" tab.
    expect(AppRoutes.isInTabs('/homework'), isFalse);
  });
}
