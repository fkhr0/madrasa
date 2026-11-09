import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

/// How a family paid. Most pay cash at the school office.
enum PaymentMethod {
  cash,
  bankTransfer,
  card,
  eWallet;

  String get label {
    switch (this) {
      case PaymentMethod.cash:
        return tr('Cash');
      case PaymentMethod.bankTransfer:
        return tr('Bank transfer');
      case PaymentMethod.card:
        return tr('Card');
      case PaymentMethod.eWallet:
        return tr('E-wallet');
    }
  }

  IconData get icon {
    switch (this) {
      case PaymentMethod.cash:
        return Icons.payments_outlined;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
      case PaymentMethod.card:
        return Icons.credit_card;
      case PaymentMethod.eWallet:
        return Icons.phone_iphone;
    }
  }
}

/// One payment, with the receipt number the office gives the family.
class PaymentModel {
  /// The server's ID (to void it); empty in mock data.
  final String id;
  final String receiptNumber;
  final String studentId;
  final int amount;
  final DateTime date;
  final PaymentMethod method;
  final String note;

  const PaymentModel({
    this.id = '',
    required this.receiptNumber,
    required this.studentId,
    required this.amount,
    required this.date,
    required this.method,
    this.note = '',
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
    id: json['id'] as String? ?? '',
    receiptNumber: json['receiptNumber'] as String,
    studentId: json['studentId'] as String,
    amount: json['amount'] as int,
    date: DateTime.parse(json['date'] as String).toLocal(),
    method: PaymentMethod.values.byName(json['method'] as String),
    note: json['note'] as String? ?? '',
  );
}
