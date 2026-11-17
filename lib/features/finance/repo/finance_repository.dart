import '../models/finance_settings_model.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';

abstract class FinanceRepository {
  Future<List<StudentAccountModel>> getAccounts();

  Future<StudentAccountModel?> getAccount(String studentId);

  Future<PaymentModel> recordPayment({
    required String studentId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  });

  Future<void> voidPayment(PaymentModel payment, String reason);

  Future<void> remindParent(String studentId);

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
