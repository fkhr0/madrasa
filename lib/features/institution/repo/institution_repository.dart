import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';

abstract class InstitutionRepository {
  Future<InstitutionModel> getInstitution();

  Future<AcademicYearModel> getCurrentAcademicYear();

  Future<void> updateInstitution(InstitutionModel institution);

  Future<void> updateWorkingDays(List<int> workingDays);

  Future<void> addHoliday(HolidayModel holiday);

  Future<void> updateHoliday(HolidayModel old, HolidayModel updated);

  Future<void> removeHoliday(HolidayModel holiday);
}
