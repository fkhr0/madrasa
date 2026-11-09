import '../l10n/language.dart';

/// Iraqi dinar amounts. Fees are whole dinars (no fils in practice).
class MoneyFormatter {
  MoneyFormatter._();

  static bool get _ar => AppLanguage.current.isArabic;

  /// 1250000 → "1,250,000 IQD" / "1,250,000 د.ع"
  static String iqd(int amount) => '${grouped(amount)} ${_ar ? 'د.ع' : 'IQD'}';

  /// 1250000 → "1,250,000"
  static String grouped(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer(amount < 0 ? '-' : '');

    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  /// Short form for tight spaces: 1250000 → "1.25M" / "1.25 مليون",
  /// 750000 → "750K" / "750 ألف".
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
