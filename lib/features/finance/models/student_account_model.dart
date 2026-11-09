import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/day_json.dart';
import 'payment_model.dart';
import '../../../core/l10n/language.dart';

/// One part of the year's fees, due on a date.
class InstallmentModel {
  final String name;
  final DateTime dueDate;
  final int amount;

  const InstallmentModel({
    required this.name,
    required this.dueDate,
    required this.amount,
  });
}

enum InstallmentStatus {
  paid,
  partlyPaid,
  overdue,
  dueSoon,
  upcoming;

  String get label {
    switch (this) {
      case InstallmentStatus.paid:
        return tr('Paid');
      case InstallmentStatus.partlyPaid:
        return tr('Partly paid');
      case InstallmentStatus.overdue:
        return tr('Overdue');
      case InstallmentStatus.dueSoon:
        return tr('Due soon');
      case InstallmentStatus.upcoming:
        return tr('Upcoming');
    }
  }

  Color get color {
    switch (this) {
      case InstallmentStatus.paid:
        return AppColors.success;
      case InstallmentStatus.partlyPaid:
        return AppColors.info;
      case InstallmentStatus.overdue:
        return AppColors.danger;
      case InstallmentStatus.dueSoon:
        return AppColors.warning;
      case InstallmentStatus.upcoming:
        return AppColors.neutral;
    }
  }
}

/// The family's standing for the whole year.
enum AccountStatus {
  paidInFull,
  onTrack,
  overdue;

  String get label {
    switch (this) {
      case AccountStatus.paidInFull:
        return tr('Paid in full');
      case AccountStatus.onTrack:
        return tr('On track');
      case AccountStatus.overdue:
        return tr('Overdue');
    }
  }

  Color get color {
    switch (this) {
      case AccountStatus.paidInFull:
        return AppColors.success;
      case AccountStatus.onTrack:
        return AppColors.info;
      case AccountStatus.overdue:
        return AppColors.danger;
    }
  }
}

/// A student's fees for the study year: what is owed, when, and what was
/// paid. Payments fill the installments in order, oldest first.
class StudentAccountModel {
  final String studentId;
  final String studentName;
  final String className;
  final String parentId;
  final String parentName;

  final int tuition;

  /// 0 when the student doesn't use the school bus.
  final int busFee;

  /// e.g. 10 for a sibling discount. Applies to tuition only.
  final int discountPercent;
  final String discountReason;

  /// The school's installment dates (usually three in the year).
  final List<DateTime> dueDates;
  final List<PaymentModel> payments;

  const StudentAccountModel({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.parentId,
    required this.parentName,
    required this.tuition,
    required this.busFee,
    required this.dueDates,
    required this.payments,
    this.discountPercent = 0,
    this.discountReason = '',
  });

  int get discount => (tuition * discountPercent / 100).round();

  int get total => tuition + busFee - discount;

  int get paid => payments.fold(0, (sum, p) => sum + p.amount);

  int get balance => total - paid;

  /// The total split evenly; the last installment takes the rounding.
  List<InstallmentModel> get installments {
    const names = ['1st', '2nd', '3rd', '4th', '5th', '6th'];
    final n = dueDates.length;
    // Round to the nearest 1,000 dinars, as offices do.
    final part = (total / n / 1000).round() * 1000;

    return [
      for (var i = 0; i < n; i++)
        InstallmentModel(
          name: tr('{0} installment', [names[i]]),
          dueDate: dueDates[i],
          amount: i == n - 1 ? total - part * (n - 1) : part,
        ),
    ];
  }

  /// What should have been paid by [now].
  int dueBy(DateTime now) => installments
      .where((i) => !i.dueDate.isAfter(now))
      .fold(0, (sum, i) => sum + i.amount);

  int overdueAmount(DateTime now) {
    final missing = dueBy(now) - paid;
    return missing > 0 ? missing : 0;
  }

  AccountStatus status(DateTime now) {
    if (balance <= 0) return AccountStatus.paidInFull;
    if (overdueAmount(now) > 0) return AccountStatus.overdue;

    return AccountStatus.onTrack;
  }

  /// How much of installment [index] the payments cover.
  int coveredOf(int index) {
    final list = installments;
    final before = list.take(index).fold(0, (sum, i) => sum + i.amount);
    final covered = paid - before;

    return covered.clamp(0, list[index].amount);
  }

  InstallmentStatus installmentStatus(int index, DateTime now) {
    final installment = installments[index];
    final covered = coveredOf(index);

    if (covered >= installment.amount) return InstallmentStatus.paid;
    if (installment.dueDate.isBefore(now)) return InstallmentStatus.overdue;
    if (covered > 0) return InstallmentStatus.partlyPaid;
    if (installment.dueDate.difference(now).inDays <= 14) {
      return InstallmentStatus.dueSoon;
    }

    return InstallmentStatus.upcoming;
  }

  /// The first installment not fully paid, with what is left of it.
  (InstallmentModel, int)? nextDue() {
    final list = installments;
    for (var i = 0; i < list.length; i++) {
      final left = list[i].amount - coveredOf(i);
      if (left > 0) return (list[i], left);
    }

    return null;
  }

  factory StudentAccountModel.fromJson(Map<String, dynamic> json) =>
      StudentAccountModel(
        studentId: json['studentId'] as String,
        studentName: json['studentName'] as String,
        className: json['className'] as String? ?? '',
        parentId: json['parentId'] as String? ?? '',
        parentName: json['parentName'] as String? ?? '',
        tuition: json['tuition'] as int,
        busFee: json['busFee'] as int? ?? 0,
        discountPercent: json['discountPercent'] as int? ?? 0,
        discountReason: json['discountReason'] as String? ?? '',
        dueDates: [
          for (final d in json['dueDates'] as List) parseDay(d as String),
        ],
        payments: [
          for (final p in json['payments'] as List? ?? const [])
            PaymentModel.fromJson(p as Map<String, dynamic>),
        ],
      );

  StudentAccountModel withPayment(PaymentModel payment) {
    return StudentAccountModel(
      studentId: studentId,
      studentName: studentName,
      className: className,
      parentId: parentId,
      parentName: parentName,
      tuition: tuition,
      busFee: busFee,
      dueDates: dueDates,
      payments: [...payments, payment],
      discountPercent: discountPercent,
      discountReason: discountReason,
    );
  }
}
