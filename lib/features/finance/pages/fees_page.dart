import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../parent/widgets/child_switcher.dart';
import '../providers/finance_provider.dart';
import 'student_account_page.dart';
import '../../../core/l10n/language.dart';

/// Parent: the selected child's school fees (read-only).
class FeesPage extends ConsumerWidget {
  const FeesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentId = ref.watch(activeStudentIdProvider);
    final account = ref.watch(accountProvider(studentId));

    return Scaffold(
      appBar: AppBar(title: Text(tr('School fees'))),
      body: AsyncValueView(
        value: account,
        data: (account) => account == null
            ? EmptyState(
                icon: Icons.receipt_long_outlined,
                title: tr('No fees on file'),
              )
            : StudentAccountView(
                account: account,
                isAdmin: false,
                header: const Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: ChildSwitcher(),
                ),
              ),
      ),
    );
  }
}
