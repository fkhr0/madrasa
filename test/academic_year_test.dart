import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/utils/grade_scale.dart';
import 'package:school/features/institution/data/mock_institution.dart';

void main() {
  final year = MockInstitution.academicYear;

  group('AcademicYearModel', () {
    test('only covers the study year', () {
      expect(year.contains(DateTime(2026, 9, 19)), isFalse);
      expect(year.contains(DateTime(2026, 9, 20)), isTrue);
      expect(year.contains(DateTime(2027, 6, 10)), isTrue);
      expect(year.contains(DateTime(2027, 6, 11)), isFalse);
    });

    test('Friday, Saturday and holidays are not school days', () {
      expect(year.isSchoolDay(DateTime(2026, 11, 4)), isTrue); // Wednesday
      expect(year.isSchoolDay(DateTime(2026, 11, 6)), isFalse); // Friday
      expect(year.isSchoolDay(DateTime(2026, 11, 7)), isFalse); // Saturday
      expect(year.isSchoolDay(DateTime(2027, 1, 6)), isFalse); // Army Day
    });

    test('next school day skips the weekend and the mid-year break', () {
      // Friday → Sunday
      expect(year.nextSchoolDay(DateTime(2026, 11, 6)), DateTime(2026, 11, 8));
      // During the break → first day of the second semester
      expect(year.nextSchoolDay(DateTime(2027, 1, 27)), DateTime(2027, 2, 7));
      // Before the year starts → the first day
      expect(year.nextSchoolDay(DateTime(2026, 8, 1)), DateTime(2026, 9, 20));
    });

    test('week numbers start at 1', () {
      expect(year.weekNumber(DateTime(2026, 9, 20)), 1);
      expect(year.weekNumber(DateTime(2026, 9, 24)), 1);
      expect(year.weekNumber(DateTime(2026, 9, 27)), 2);
    });

    test('knows the term and the holiday of a day', () {
      expect(year.termOn(DateTime(2026, 11, 4))?.name, 'First semester');
      expect(year.termOn(DateTime(2027, 3, 1))?.name, 'Second semester');
      expect(year.holidayOn(DateTime(2027, 1, 30))?.name, 'Mid-year break');
    });
  });

  group('GradeScale (Iraq)', () {
    test('bands', () {
      expect(GradeScale.labelFor(95), 'Excellent');
      expect(GradeScale.labelFor(85), 'Very good');
      expect(GradeScale.labelFor(72), 'Good');
      expect(GradeScale.labelFor(60), 'Average');
      expect(GradeScale.labelFor(50), 'Pass');
      expect(GradeScale.labelFor(49.9), 'Fail');
    });
  });
}
