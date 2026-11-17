library;

class _ArabicNoun {
  final String one, two, few, many, hundred;

  const _ArabicNoun(this.one, this.two, this.few, this.many, this.hundred);

  String say(int n) {
    if (n == 1) return one;
    if (n == 2) return two;
    final lastTwo = n % 100;
    if (lastTwo >= 3 && lastTwo <= 10) return '$n $few';
    if (lastTwo >= 11) return '$n $many';
    return '$n $hundred';
  }
}

const _day = _ArabicNoun('يوم واحد', 'يومان', 'أيام', 'يوماً', 'يوم');
const _minute = _ArabicNoun(
  'دقيقة واحدة',
  'دقيقتان',
  'دقائق',
  'دقيقة',
  'دقيقة',
);
const _lesson = _ArabicNoun('حصة واحدة', 'حصتان', 'حصص', 'حصة', 'حصة');
const _student = _ArabicNoun('طالب واحد', 'طالبان', 'طلاب', 'طالباً', 'طالب');
const _exam = _ArabicNoun(
  'امتحان واحد',
  'امتحانان',
  'امتحانات',
  'امتحاناً',
  'امتحان',
);
const _homework = _ArabicNoun(
  'واجب واحد',
  'واجبان',
  'واجبات',
  'واجباً',
  'واجب',
);
const _stop = _ArabicNoun('موقف واحد', 'موقفان', 'مواقف', 'موقفاً', 'موقف');
const _classroom = _ArabicNoun('صف واحد', 'صفان', 'صفوف', 'صفاً', 'صف');
const _score = _ArabicNoun('درجة واحدة', 'درجتان', 'درجات', 'درجة', 'درجة');
const _rider = _ArabicNoun('راكب واحد', 'راكبان', 'ركاب', 'راكباً', 'راكب');
const _letter = _ArabicNoun('حرف واحد', 'حرفان', 'أحرف', 'حرفاً', 'حرف');

const _arabicNouns = {
  'أيام': _day,
  'يوماً': _day,
  'دقيقة': _minute,
  'دقائق': _minute,
  'حصص': _lesson,
  'حصة': _lesson,
  'طلاب': _student,
  'طالب': _student,
  'طالباً': _student,
  'امتحانات': _exam,
  'واجبات': _homework,
  'مواقف': _stop,
  'صفوف': _classroom,
  'درجات': _score,
  'راكب': _rider,
  'ركاب': _rider,
  'أحرف': _letter,
};

final _arabicCount = RegExp(
  '(?<![\\d.,])(\\d+) (${_arabicNouns.keys.join('|')})(?![\\u0600-\\u06FF])',
);

const _englishSingular = {
  'days': 'day',
  'minutes': 'minute',
  'classes': 'class',
  'students': 'student',
  'exams': 'exam',
  'stops': 'stop',
  'riders': 'rider',
  'lessons': 'lesson',
  'scores': 'score',
  'characters': 'character',
  'points': 'point',
  'school days': 'school day',
};

final _englishOne = RegExp(
  '(?<![\\d.,])1 (${_englishSingular.keys.join('|')})\\b',
);

String fixCounts(String text, {required bool arabic}) => arabic
    ? text.replaceAllMapped(
        _arabicCount,
        (m) => _arabicNouns[m[2]]!.say(int.parse(m[1]!)),
      )
    : text.replaceAllMapped(_englishOne, (m) => '1 ${_englishSingular[m[1]]}');
