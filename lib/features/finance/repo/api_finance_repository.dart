import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/finance_settings_model.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';
import 'finance_repository.dart';

/// Fees on the school API (server/src/features/finance).
class ApiFinanceRepository implements FinanceRepository {
  final ApiClient _api;

  const ApiFinanceRepository(this._api);

  @override
  Future<List<StudentAccountModel>> getAccounts() => _act(
    () async => [
      for (final json in await _api.get('/finance/accounts') as List)
        StudentAccountModel.fromJson(json as Map<String, dynamic>),
    ],
  );

  @override
  Future<StudentAccountModel?> getAccount(String studentId) => _act(
    () async => StudentAccountModel.fromJson(
      await _api.get('/finance/accounts/$studentId') as Map<String, dynamic>,
    ),
  );

  @override
  Future<PaymentModel> recordPayment({
    required String studentId,
    required int amount,
    required PaymentMethod method,
    String note = '',
  }) => _act(
    () async => PaymentModel.fromJson(
      await _api.post('/finance/accounts/$studentId/payments', {
            'amount': amount,
            'method': method.name,
            'note': note,
          })
          as Map<String, dynamic>,
    ),
  );

  @override
  Future<void> voidPayment(PaymentModel payment, String reason) => _act(
    () => _api.post('/finance/payments/${payment.id}/void', {'reason': reason}),
  );

  @override
  Future<void> remindParent(String studentId) =>
      _act(() => _api.post('/finance/accounts/$studentId/remind'));

  @override
  Future<void> setDiscount(String studentId, int percent, String reason) =>
      _act(
        () => _api.put('/finance/accounts/$studentId/discount', {
          'percent': percent,
          'reason': reason,
        }),
      );

  @override
  Future<FinanceSettingsModel> getSettings() => _act(
    () async => FinanceSettingsModel.fromJson(
      await _api.get('/finance/settings') as Map<String, dynamic>,
    ),
  );

  @override
  Future<void> saveSettings(FinanceSettingsModel settings) =>
      _act(() => _api.put('/finance/settings', settings.toJson()));

  /// The server's message as a [FinanceException], like the mock throws.
  Future<T> _act<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw FinanceException(e.message);
    }
  }
}
