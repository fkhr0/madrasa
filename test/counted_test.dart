import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/l10n/counted.dart';
import 'package:school/core/l10n/language.dart';

void main() {
  String ar(String text) => fixCounts(text, arabic: true);

  test('Arabic says numbers before nouns properly', () {
    expect(ar('متأخر 1 أيام'), 'متأخر يوم واحد');
    expect(ar('متأخر 2 أيام'), 'متأخر يومان');
    expect(ar('متأخر 3 أيام'), 'متأخر 3 أيام');
    expect(ar('متأخر 10 أيام'), 'متأخر 10 أيام');
    expect(ar('متأخر 11 أيام'), 'متأخر 11 يوماً');
    expect(ar('100 أيام'), '100 يوم');
    expect(ar('بعد 2 دقيقة'), 'بعد دقيقتان');
    expect(ar('بعد 5 دقيقة'), 'بعد 5 دقائق');
    expect(ar('بعد 25 دقيقة'), 'بعد 25 دقيقة');
    expect(ar('1 طلاب · 2 حصص'), 'طالب واحد · حصتان');
  });

  test('numbers that are not counts stay as they are', () {
    expect(ar('تصبح الحصة 3 يوم الأحد فارغة'), 'تصبح الحصة 3 يوم الأحد فارغة');
    expect(ar('الساعة 2:30 · 4.5 أيام'), 'الساعة 2:30 · 4.5 أيام');
    expect(ar('الحصص 2'), 'الحصص 2');
  });

  test('English: 1 day, 2 days', () {
    expect(fixCounts('1 days overdue', arabic: false), '1 day overdue');
    expect(fixCounts('2 days overdue', arabic: false), '2 days overdue');
    expect(fixCounts('11 days', arabic: false), '11 days');
  });

  test('tr() applies it to every translated text', () {
    AppLanguage.current = AppLanguage.ar;
    addTearDown(() => AppLanguage.current = AppLanguage.en);
    expect(
      tr('{0} days late · late work is still accepted', [2]),
      startsWith('متأخر يومان'),
    );
  });
}
