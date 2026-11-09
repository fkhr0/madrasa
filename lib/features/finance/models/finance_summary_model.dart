import 'payment_model.dart';
import 'student_account_model.dart';

/// Collection progress of one class.
class ClassCollection {
  final String className;
  final int collected;
  final int expected;

  const ClassCollection({
    required this.className,
    required this.collected,
    required this.expected,
  });

  double get rate => expected == 0 ? 0 : collected / expected;
}

/// The school's money for the year, worked out from the accounts.
class FinanceSummaryModel {
  final int expected;
  final int collected;
  final int overdueAmount;
  final int overdueFamilies;
  final int paidInFullCount;
  final int collectedThisMonth;
  final List<ClassCollection> byClass;

  /// Newest first.
  final List<PaymentModel> recentPayments;

  const FinanceSummaryModel({
    required this.expected,
    required this.collected,
    required this.overdueAmount,
    required this.overdueFamilies,
    required this.paidInFullCount,
    required this.collectedThisMonth,
    required this.byClass,
    required this.recentPayments,
  });

  int get outstanding => expected - collected;

  double get collectionRate => expected == 0 ? 0 : collected / expected;

  factory FinanceSummaryModel.from(
    List<StudentAccountModel> accounts,
    DateTime now,
  ) {
    final classes = <String, (int, int)>{};
    final payments = <PaymentModel>[];
    var thisMonth = 0;

    for (final a in accounts) {
      final (collected, expected) = classes[a.className] ?? (0, 0);
      classes[a.className] = (collected + a.paid, expected + a.total);

      for (final p in a.payments) {
        payments.add(p);
        if (p.date.year == now.year && p.date.month == now.month) {
          thisMonth += p.amount;
        }
      }
    }

    final byClass = [
      for (final e in classes.entries)
        ClassCollection(
          className: e.key,
          collected: e.value.$1,
          expected: e.value.$2,
        ),
    ]..sort((a, b) => a.rate.compareTo(b.rate)); // weakest first

    return FinanceSummaryModel(
      expected: accounts.fold(0, (sum, a) => sum + a.total),
      collected: accounts.fold(0, (sum, a) => sum + a.paid),
      overdueAmount: accounts.fold(0, (sum, a) => sum + a.overdueAmount(now)),
      overdueFamilies: accounts
          .where((a) => a.status(now) == AccountStatus.overdue)
          .length,
      paidInFullCount: accounts
          .where((a) => a.status(now) == AccountStatus.paidInFull)
          .length,
      collectedThisMonth: thisMonth,
      byClass: byClass,
      recentPayments: (payments..sort((a, b) => b.date.compareTo(a.date)))
          .take(5)
          .toList(),
    );
  }
}
