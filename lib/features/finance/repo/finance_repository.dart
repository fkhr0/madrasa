import '../models/finance_settings_model.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';

/// Tuition and bus fees (administrator) and a family's own fees (parent).
/// MockFinanceRepository or ApiFinanceRepository, receipts are numbered by
/// the server, never by the phone. Failures throw [FinanceException].
abstract class FinanceRepository {
  /// Every student's account for the current study year.
  Future<List<StudentAccountModel>> getAccounts();

  Future<StudentAccountModel?> getAccount(String studentId);

  /// Records money the office received. Throws [FinanceException] when the
  /// amount is not positive or is more than the balance.
  Future<PaymentModel> recordPayment({
    required String studentId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  });

  /// A wrong payment stops counting; it stays in the records with [reason].
  Future<void> voidPayment(PaymentModel payment, String reason);

  /// Sends the parent a polite reminder about what is due.
  Future<void> remindParent(String studentId);

  /// 0 removes the discount.
  Future<void> setDiscount(String studentId, int percent, String reason);

  Future<FinanceSettingsModel> getSettings();

  Future<void> saveSettings(FinanceSettingsModel settings);
}

class FinanceException implements Exception {
  final String message;

  const FinanceException(this.message);

  @override
  String toString() => message;
}
