import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/finance/models/finance_settings_model.dart';
import 'package:school/features/finance/models/payment_model.dart';
import 'package:school/features/finance/models/student_account_model.dart';

void main() {
  test('an account from the server works out like the mock', () {
    final account = StudentAccountModel.fromJson({
      'studentId': 'STU-2026-0142',
      'studentName': 'Zainab Haider',
      'className': '5th Scientific – A',
      'parentId': 'PAR-2026-0142',
      'parentName': 'Haider Jasim',
      'tuition': 2250000,
      'busFee': 600000,
      'discountPercent': 10,
      'discountReason': 'Siblings at the school',
      'dueDates': ['2026-10-01', '2027-01-01', '2027-04-01'],
      'payments': [
        {
          'id': 'p1',
          'receiptNumber': 'RCP-2026-0007',
          'studentId': 'STU-2026-0142',
          'amount': 875000,
          'date': '2026-09-28T06:00:00.000Z',
          'method': 'cash',
          'note': '',
        },
      ],
    });

    expect(account.total, 2625000);
    expect(account.installments.map((i) => i.amount), [875000, 875000, 875000]);
    expect(account.payments.single.method, PaymentMethod.cash);
    expect(account.payments.single.id, 'p1');
    expect(account.status(DateTime(2026, 11, 8)), AccountStatus.onTrack);
    expect(account.status(DateTime(2027, 1, 2)), AccountStatus.overdue);
  });

  test('fee settings go back with null for "the school\'s tuition"', () {
    final json = FinanceSettingsModel(
      tuition: 2000000,
      busFee: 600000,
      dueDates: [DateTime(2026, 10, 1)],
      classTuition: const [
        ClassTuitionModel(
          classId: 'cls-6c',
          className: '6th',
          tuition: 2500000,
        ),
        ClassTuitionModel(classId: 'cls-4a', className: '4th'),
      ],
    ).toJson();

    expect(json['dueDates'], ['2026-10-01']);
    expect(json['classTuition'], {'cls-6c': 2500000, 'cls-4a': null});
  });
}
