import '../../../core/network/api_exception.dart';
import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';

/// MockInstitutionRepository (no server) or ApiInstitutionRepository.
abstract class InstitutionRepository {
  /// The school of the signed-in user.
  Future<InstitutionModel> getInstitution();

  /// The study year currently running (or about to start).
  Future<AcademicYearModel> getCurrentAcademicYear();

  // ---------- Administrator only ----------
  Future<void> updateInstitution(InstitutionModel institution);

  /// The days with classes ([DateTime.monday] ... [DateTime.sunday]).
  Future<void> updateWorkingDays(List<int> workingDays);

  Future<void> addHoliday(HolidayModel holiday);

  /// Replaces [old] with [updated] (same holiday, new name, type or dates).
  Future<void> updateHoliday(HolidayModel old, HolidayModel updated);

  /// Official holidays can't be removed (throws [ApiException]).
  Future<void> removeHoliday(HolidayModel holiday);
}
