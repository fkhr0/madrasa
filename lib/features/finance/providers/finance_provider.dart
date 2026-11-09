import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/providers/clock_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../models/finance_settings_model.dart';
import '../models/finance_summary_model.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';
import '../repo/api_finance_repository.dart';
import '../repo/finance_repository.dart';
import '../repo/mock_finance_repository.dart';

/// The server when API_URL is set, otherwise the in-memory mock.
final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => AppConfig.useApi
      ? ApiFinanceRepository(watchApi(ref))
      : MockFinanceRepository(notifier: ref.read(demoNotifierProvider)),
);

/// The school's fee settings (office).
final financeSettingsProvider = FutureProvider<FinanceSettingsModel>(
  (ref) => ref.watch(financeRepositoryProvider).getSettings(),
);

final accountsProvider = FutureProvider<List<StudentAccountModel>>(
  (ref) => ref.watch(financeRepositoryProvider).getAccounts(),
);

final accountProvider = FutureProvider.family<StudentAccountModel?, String>(
  (ref, studentId) =>
      ref.watch(financeRepositoryProvider).getAccount(studentId),
);

/// The year's totals, worked out from the accounts.
final financeSummaryProvider = Provider<AsyncValue<FinanceSummaryModel>>((ref) {
  final DateTime now = ref.watch(nowProvider);
  return ref
      .watch(accountsProvider)
      .whenData((accounts) => FinanceSummaryModel.from(accounts, now));
});

/// Filter chips on the Finance page (null = all).
final accountFilterProvider = StateProvider<AccountStatus?>((ref) => null);

final accountSearchProvider = StateProvider<String>((ref) => '');

/// Accounts matching the filter and search, overdue ones first.
final filteredAccountsProvider = Provider<List<StudentAccountModel>>((ref) {
  final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
  final filter = ref.watch(accountFilterProvider);
  final query = ref.watch(accountSearchProvider).trim().toLowerCase();
  final DateTime now = ref.watch(nowProvider);

  return accounts
      .where((a) => filter == null || a.status(now) == filter)
      .where(
        (a) =>
            query.isEmpty ||
            a.studentName.toLowerCase().contains(query) ||
            a.className.toLowerCase().contains(query) ||
            a.studentId.toLowerCase().contains(query),
      )
      .toList()
    ..sort((a, b) => b.overdueAmount(now).compareTo(a.overdueAmount(now)));
});

final financeActionsProvider = Provider<FinanceActions>(FinanceActions.new);

class FinanceActions {
  final Ref _ref;

  FinanceActions(this._ref);

  FinanceRepository get _repository => _ref.read(financeRepositoryProvider);

  /// Throws [FinanceException] for a wrong amount.
  Future<PaymentModel> recordPayment({
    required String studentId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  }) async {
    final payment = await _repository.recordPayment(
      studentId: studentId,
      amount: amount,
      method: method,
      note: note,
    );
    _ref
      ..invalidate(accountsProvider)
      ..invalidate(accountProvider(studentId));
    return payment;
  }

  Future<void> remindParent(String studentId) =>
      _repository.remindParent(studentId);

  Future<void> voidPayment(PaymentModel payment, String reason) async {
    await _repository.voidPayment(payment, reason);
    _reload(payment.studentId);
  }

  Future<void> setDiscount(String studentId, int percent, String reason) async {
    await _repository.setDiscount(studentId, percent, reason);
    _reload(studentId);
  }

  /// Every account's total can change (tuition, bus fee, dates).
  Future<void> saveSettings(FinanceSettingsModel settings) async {
    await _repository.saveSettings(settings);
    _ref
      ..invalidate(financeSettingsProvider)
      ..invalidate(accountsProvider)
      ..invalidate(accountProvider);
  }

  void _reload(String studentId) => _ref
    ..invalidate(accountsProvider)
    ..invalidate(accountProvider(studentId));
}
