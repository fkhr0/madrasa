import '../l10n/counted.dart';
import '../l10n/language.dart';

/// Turns dates into short, friendly text, in the app's language. Arabic
/// uses the month names of Iraq and the Levant (كانون الثاني، شباط...) and
/// Western digits.
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

  /// "Wednesday"
  static String weekday(DateTime date) => weekdayName(date.weekday);

  /// 7 → "Sunday" (DateTime.monday = 1 ... DateTime.sunday = 7).
  static String weekdayName(int weekday) =>
      (_ar ? _weekdaysAr : _weekdays)[weekday - 1];

  /// "Wed"
  static String weekdayShort(DateTime date) => _ar
      // Arabic day names are short already; drop "ال" (the).
      ? weekday(date).replaceFirst('ال', '')
      : weekday(date).substring(0, 3);

  /// "November"
  static String monthName(DateTime date) =>
      (_ar ? _monthsAr : _months)[date.month - 1];

  /// "Nov" (Arabic month names aren't shortened).
  static String monthShort(DateTime date) =>
      _ar ? monthName(date) : monthName(date).substring(0, 3);

  /// "4 Nov"
  static String dayMonth(DateTime date) => '${date.day} ${monthShort(date)}';

  /// "Wednesday, 4 November"
  static String fullDate(DateTime date) =>
      '${weekday(date)}${_ar ? '،' : ','} ${date.day} ${monthName(date)}';

  /// "08:30"
  static String time(DateTime date) =>
      '${_two(date.hour)}:${_two(date.minute)}';

  /// "Today", "Tomorrow", "Yesterday" or "Wed, 4 Nov"
  static String relativeDay(DateTime date) {
    final difference = _daysBetween(DateTime.now(), date);

    if (difference == 0) return _ar ? 'اليوم' : 'Today';
    if (difference == 1) return _ar ? 'غداً' : 'Tomorrow';
    if (difference == -1) return _ar ? 'أمس' : 'Yesterday';

    return '${weekdayShort(date)}${_ar ? '،' : ','} ${dayMonth(date)}';
  }

  /// "Due today", "Due in 3 days", "2 days overdue"
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

  /// For chat lists: "09:41" today, "Yesterday", or "4 Nov".
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
