import '../l10n/counted.dart';
import '../l10n/language.dart';

class DateFormatter {
  DateFormatter._();

  static bool get _ar => AppLanguage.current.isArabic;

  static const _weekdaysAr = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const _monthsAr = [
    'كانون الثاني',
    'شباط',
    'آذار',
    'نيسان',
    'أيار',
    'حزيران',
    'تموز',
    'آب',
    'أيلول',
    'تشرين الأول',
    'تشرين الثاني',
    'كانون الأول',
  ];

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String weekday(DateTime date) => weekdayName(date.weekday);

  static String weekdayName(int weekday) =>
      (_ar ? _weekdaysAr : _weekdays)[weekday - 1];

  static String weekdayShort(DateTime date) => _ar
      ? weekday(date).replaceFirst('ال', '')
      : weekday(date).substring(0, 3);

  static String monthName(DateTime date) =>
      (_ar ? _monthsAr : _months)[date.month - 1];

  static String monthShort(DateTime date) =>
      _ar ? monthName(date) : monthName(date).substring(0, 3);

  static String dayMonth(DateTime date) => '${date.day} ${monthShort(date)}';

  static String fullDate(DateTime date) =>
      '${weekday(date)}${_ar ? '،' : ','} ${date.day} ${monthName(date)}';

  static String time(DateTime date) =>
      '${_two(date.hour)}:${_two(date.minute)}';

  static String relativeDay(DateTime date) {
    final difference = _daysBetween(DateTime.now(), date);

    if (difference == 0) return _ar ? 'اليوم' : 'Today';
    if (difference == 1) return _ar ? 'غداً' : 'Tomorrow';
    if (difference == -1) return _ar ? 'أمس' : 'Yesterday';

    return '${weekdayShort(date)}${_ar ? '،' : ','} ${dayMonth(date)}';
  }

  static String dueLabel(DateTime due) {
    final days = _daysBetween(DateTime.now(), due);

    if (_ar) {
      if (days == 0) return 'مستحق اليوم';
      if (days == 1) return 'مستحق غداً';
      if (days > 1) {
        return fixCounts('مستحق خلال $days أيام', arabic: true);
      }
      return fixCounts('متأخر ${-days} أيام', arabic: true);
    }
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days > 1) return 'Due in $days days';
    if (days == -1) return '1 day overdue';

    return '${-days} days overdue';
  }

  static String shortStamp(DateTime date) {
    final days = _daysBetween(date, DateTime.now());

    if (days == 0) return time(date);
    if (days == 1) return _ar ? 'أمس' : 'Yesterday';

    return dayMonth(date);
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);

    return b.difference(a).inDays;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
