import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/theme/app_palette.dart';
import 'package:school/features/auth/data/mock_users.dart';
import 'package:school/features/people/models/account_credentials_model.dart';
import 'package:school/features/people/widgets/credentials_sheet.dart';

void main() {
  testWidgets('"Copy both" copies a ready-to-send message', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.light]),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showCredentialsSheet(
              context,
              const AccountCredentialsModel(
                user: MockUsers.teacher,
                temporaryPassword: 'aB3dEf7h',
              ),
              title: 'Account created',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy both as a message'));
    await tester.pump();

    expect(clipboard, contains('School ID: TCH-2019-0031'));
    expect(clipboard, contains('Temporary password: aB3dEf7h'));
    // The confirmation shows on the button, inside the sheet.
    expect(find.textContaining('Copied'), findsOneWidget);

    await tester.tap(find.text('Copy').first);
    await tester.pump();
    expect(clipboard, 'TCH-2019-0031');
  });
}
