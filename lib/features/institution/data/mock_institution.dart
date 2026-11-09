import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';
import '../models/term_model.dart';

/// Fake school and study year. In production the administrator sets these.
/// Religious holidays are approximate: they depend on the moon sighting.
class MockInstitution {
  MockInstitution._();

  static const institution = InstitutionModel(
    id: 'inst-001',
    name: 'Al-Noor Preparatory School',
    city: 'Baghdad',
    address: 'Al-Mansour, Baghdad',
    latitude: 33.315,
    longitude: 44.365,
  );

  static final academicYear = AcademicYearModel(
    name: '2026–2027',
    start: DateTime(2026, 9, 20),
    end: DateTime(2027, 6, 10),
    terms: [
      TermModel(
        name: 'First semester',
        start: DateTime(2026, 9, 20),
        end: DateTime(2027, 1, 21),
      ),
      TermModel(
        name: 'Second semester',
        start: DateTime(2027, 2, 7),
        end: DateTime(2027, 6, 10),
      ),
    ],
    holidays: [
      HolidayModel(
        name: 'Iraqi National Day',
        type: HolidayType.national,
        isOfficial: true,
        start: DateTime(2026, 10, 3),
      ),
      HolidayModel(
        name: 'Christmas',
        type: HolidayType.religious,
        isOfficial: true,
        start: DateTime(2026, 12, 25),
      ),
      HolidayModel(
        name: 'New Year\'s Day',
        type: HolidayType.national,
        isOfficial: true,
        start: DateTime(2027, 1, 1),
      ),
      HolidayModel(
        name: 'Army Day',
        type: HolidayType.national,
        isOfficial: true,
        start: DateTime(2027, 1, 6),
      ),
      HolidayModel(
        name: 'Mid-year break',
        type: HolidayType.schoolBreak,
        start: DateTime(2027, 1, 24),
        end: DateTime(2027, 2, 4),
      ),
      HolidayModel(
        name: 'Eid al-Fitr',
        type: HolidayType.religious,
        isOfficial: true,
        start: DateTime(2027, 3, 9),
        end: DateTime(2027, 3, 12),
      ),
      HolidayModel(
        name: 'Nowruz',
        type: HolidayType.national,
        isOfficial: true,
        start: DateTime(2027, 3, 21),
      ),
      HolidayModel(
        name: 'Labour Day',
        type: HolidayType.national,
        isOfficial: true,
        start: DateTime(2027, 5, 1),
      ),
      HolidayModel(
        name: 'Eid al-Adha',
        type: HolidayType.religious,
        isOfficial: true,
        start: DateTime(2027, 5, 16),
        end: DateTime(2027, 5, 19),
      ),
      HolidayModel(
        name: 'Eid al-Ghadir',
        type: HolidayType.religious,
        isOfficial: true,
        start: DateTime(2027, 5, 24),
      ),
      HolidayModel(
        name: 'Islamic New Year',
        type: HolidayType.religious,
        isOfficial: true,
        start: DateTime(2027, 6, 6),
      ),
    ],
  );
}
