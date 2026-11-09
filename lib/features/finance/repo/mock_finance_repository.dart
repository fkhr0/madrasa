import '../../../core/router/app_routes.dart';
import '../../../core/utils/money_formatter.dart';
import '../../notifications/data/demo_notifier.dart';
import '../../notifications/models/notification_model.dart';
import '../data/mock_finance.dart';
import '../models/finance_settings_model.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';
import 'finance_repository.dart';

/// Keeps accounts in memory; payments and reminders reach the parent
/// through [DemoNotifier] (push notifications in production).
class MockFinanceRepository implements FinanceRepository {
  final DemoNotifier notifier;

  MockFinanceRepository({required this.notifier});

  final List<StudentAccountModel> _accounts = MockFinance.accounts();
  var _settings = FinanceSettingsModel(
    tuition: 2000000,
    busFee: MockFinance.busFee,
    dueDates: MockFinance.dueDates,
    classTuition: const [],
  );
  int _receipts = 500;
  int _notifications = 0;

  @override
  Future<List<StudentAccountModel>> getAccounts() async =>
      [..._accounts]..sort((a, b) => a.studentName.compareTo(b.studentName));

  @override
  Future<StudentAccountModel?> getAccount(String studentId) async {
    for (final a in _accounts) {
      if (a.studentId == studentId) return a;
    }

    return null;
  }

  @override
  Future<PaymentModel> recordPayment({
    required String studentId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  }) async {
    final index = _accounts.indexWhere((a) => a.studentId == studentId);
    final account = _accounts[index];

    if (amount <= 0) {
      throw const FinanceException('Enter an amount above zero.');
    }
    if (amount > account.balance) {
      throw FinanceException(
        'That is more than the balance '
        '(${MoneyFormatter.iqd(account.balance)}).',
      );
    }

    final payment = PaymentModel(
      id: 'pay-$_receipts',
      receiptNumber: 'RCP-2026-${(++_receipts).toString().padLeft(4, '0')}',
      studentId: studentId,
      amount: amount,
      date: DateTime.now(),
      method: method,
      note: note,
    );
    final updated = account.withPayment(payment);
    _accounts[index] = updated;

    _notify(
      updated,
      title: 'Payment received · ${MoneyFormatter.iqd(amount)}',
      body: updated.balance == 0
          ? '${updated.studentName}\'s fees are paid in full. Thank you!'
          : 'Receipt ${payment.receiptNumber} · '
                'balance ${MoneyFormatter.iqd(updated.balance)}',
    );

    return payment;
  }

  @override
  Future<void> voidPayment(PaymentModel payment, String reason) async {
    _replace(
      payment.studentId,
      (a) => _copy(a, payments: [...a.payments]..remove(payment)),
    );
  }

  @override
  Future<void> setDiscount(String studentId, int percent, String reason) async {
    _replace(
      studentId,
      (a) => _copy(a, discountPercent: percent, discountReason: reason),
    );
  }

  @override
  Future<FinanceSettingsModel> getSettings() async => _settings;

  @override
  Future<void> saveSettings(FinanceSettingsModel settings) async =>
      _settings = settings;

  void _replace(
    String studentId,
    StudentAccountModel Function(StudentAccountModel) change,
  ) {
    final i = _accounts.indexWhere((a) => a.studentId == studentId);
    if (i != -1) _accounts[i] = change(_accounts[i]);
  }

  static StudentAccountModel _copy(
    StudentAccountModel a, {
    List<PaymentModel>? payments,
    int? discountPercent,
    String? discountReason,
  }) => StudentAccountModel(
    studentId: a.studentId,
    studentName: a.studentName,
    className: a.className,
    parentId: a.parentId,
    parentName: a.parentName,
    tuition: a.tuition,
    busFee: a.busFee,
    dueDates: a.dueDates,
    payments: payments ?? a.payments,
    discountPercent: discountPercent ?? a.discountPercent,
    discountReason: discountReason ?? a.discountReason,
  );

  @override
  Future<void> remindParent(String studentId) async {
    final account = (await getAccount(studentId))!;
    final now = DateTime.now();
    final overdue = account.overdueAmount(now);
    final next = account.nextDue();

    _notify(
      account,
      title: overdue > 0
          ? 'School fees: ${MoneyFormatter.iqd(overdue)} overdue'
          : 'School fees reminder',
      body: next == null
          ? 'Thank you, nothing is due.'
          : 'For ${account.studentName}. You can pay at the school office '
                'or by bank transfer.',
    );
  }

  void _notify(
    StudentAccountModel account, {
    required String title,
    required String body,
  }) {
    if (account.parentId.isEmpty) return;

    notifier.notify(
      [account.parentId],
      NotificationModel(
        id: 'fees-${++_notifications}',
        type: NotificationType.payment,
        title: title,
        body: body,
        createdAt: DateTime.now(),
        route: AppRoutes.fees,
      ),
    );
  }
}
