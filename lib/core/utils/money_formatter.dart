import '../l10n/language.dart';

class MoneyFormatter {
  MoneyFormatter._();

  static bool get _ar => AppLanguage.current.isArabic;

  static String iqd(int amount) => '${grouped(amount)} ${_ar ? 'د.ع' : 'IQD'}';

  static String grouped(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer(amount < 0 ? '-' : '');

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  static String compact(int amount) {
    if (amount >= 1000000) {
      final m = amount / 1000000;
      final n = m
          .toStringAsFixed(m >= 10 ? 1 : 2)
          .replaceFirst(RegExp(r'\.?0+$'), '');
      return _ar ? '$n مليون' : '${n}M';
    }
    if (amount >= 1000) {
      final k = (amount / 1000).round();
      return _ar ? '$k ألف' : '${k}K';
    }

    return '$amount';
  }
}
