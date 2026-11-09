import '../../../core/network/api_exception.dart';
import '../data/mock_institution.dart';
import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';
import 'institution_repository.dart';

/// Keeps changes in memory so the admin screens work during the session.
class MockInstitutionRepository implements InstitutionRepository {
  InstitutionModel _institution = MockInstitution.institution;
  AcademicYearModel _year = MockInstitution.academicYear;

  @override
  Future<InstitutionModel> getInstitution() async => _institution;

  @override
  Future<AcademicYearModel> getCurrentAcademicYear() async => _year;

  @override
  Future<void> updateInstitution(InstitutionModel institution) async {
    _institution = institution;
  }

  @override
  Future<void> updateWorkingDays(List<int> workingDays) async {
    _year = _year.copyWith(workingDays: [...workingDays]..sort());
  }

  @override
  Future<void> addHoliday(HolidayModel holiday) async {
    _year = _year.copyWith(
      holidays: [..._year.holidays, holiday]
        ..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  @override
  Future<void> updateHoliday(HolidayModel old, HolidayModel updated) async {
    _year = _year.copyWith(
      holidays: [
        for (final h in _year.holidays)
          if (!identical(h, old))
            h
          else if (old.isOfficial)
            // Official holidays keep their name and type; only dates move.
            HolidayModel(
              name: old.name,
              type: old.type,
              start: updated.start,
              end: updated.end,
              isOfficial: true,
            )
          else
            updated,
      ]..sort((a, b) => a.start.compareTo(b.start)),
    );
  }

  @override
  Future<void> removeHoliday(HolidayModel holiday) async {
    if (holiday.isOfficial) {
      throw ApiException(
        '${holiday.name} is an official holiday and can\'t be deleted. '
        'You can change its dates.',
        status: 409,
      );
    }
    _year = _year.copyWith(
      holidays: _year.holidays.where((h) => h != holiday).toList(),
    );
  }
}
