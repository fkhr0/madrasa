import '../../auth/data/mock_users.dart';
import '../../auth/models/user_model.dart';
import '../../people/data/mock_people.dart';
import '../../transport/data/mock_transport.dart';
import '../models/payment_model.dart';
import '../models/student_account_model.dart';

/// Fake fees for 2026–2027 until finance has a backend.
/// Amounts are typical for a private school in Baghdad.
class MockFinance {
  MockFinance._();

  /// Three installments: October, January and April.
  static final dueDates = [
    DateTime(2026, 10, 1),
    DateTime(2027, 1, 1),
    DateTime(2027, 4, 1),
  ];

  static const busFee = 600000;

  /// Yearly tuition by stage.
  static int tuitionFor(String className) {
    if (className.startsWith('6th')) return 2500000;
    if (className.startsWith('5th')) return 2250000;
    if (className.startsWith('4th')) return 2000000;

    return 1750000; // intermediate
  }

  static List<StudentAccountModel> accounts() {
    final riders = {
      for (final route in MockTransport.routes)
        for (final s in MockTransport.rosterOf(route.id)) s.id,
    };
    final students = MockPeople.all.where((u) => u.role == UserRole.student);

    var receipt = 0;
    String nextReceipt() =>
        'RCP-2026-${(++receipt).toString().padLeft(4, '0')}';

    final accounts = <StudentAccountModel>[];
    var i = 0;

    for (final student in students) {
      final isOurFamily =
          student.id == MockUsers.student.id ||
          student.id == MockUsers.secondStudent.id;
      final className = student.className ?? '';

      var account = StudentAccountModel(
        studentId: student.id,
        studentName: student.name,
        className: className,
        parentId: isOurFamily
            ? MockUsers.parent.id
            : student.id.replaceFirst('STU', 'PAR'),
        parentName: isOurFamily
            ? MockUsers.parent.name
            : 'Parent of ${student.firstName}',
        tuition: tuitionFor(className),
        busFee: riders.contains(student.id) ? busFee : 0,
        dueDates: dueDates,
        payments: const [],
        discountPercent: isOurFamily
            ? 10
            : student.name == 'Abbas Naji'
            ? 25
            : 0,
        discountReason: isOurFamily
            ? 'Siblings at the school'
            : student.name == 'Abbas Naji'
            ? 'Top of his class'
            : '',
      );

      // Zainab has paid her first installment; her brother is behind.
      final pattern = student.id == MockUsers.student.id
          ? 1
          : student.id == MockUsers.secondStudent.id
          ? 3
          : i % 5;
      i++;

      final first = account.installments.first.amount;
      final payments = switch (pattern) {
        0 => [
          (account.total, DateTime(2026, 9, 21), PaymentMethod.bankTransfer),
        ],
        1 => [(first, DateTime(2026, 9, 28), PaymentMethod.cash)],
        3 => [
          (first ~/ 2000 * 1000, DateTime(2026, 10, 12), PaymentMethod.cash),
        ],
        4 => [
          (first, DateTime(2026, 9, 30), PaymentMethod.card),
          (500000, DateTime(2026, 11, 2), PaymentMethod.eWallet),
        ],
        _ => <(int, DateTime, PaymentMethod)>[],
      };

      for (final (amount, date, method) in payments) {
        account = account.withPayment(
          PaymentModel(
            receiptNumber: nextReceipt(),
            studentId: student.id,
            amount: amount,
            date: date,
            method: method,
          ),
        );
      }
      accounts.add(account);
    }

    return accounts;
  }
}
