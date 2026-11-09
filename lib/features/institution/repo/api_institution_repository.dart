import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';
import 'institution_repository.dart';
import '../../../core/l10n/language.dart';

/// The school and its study year, on the school API.
/// The server decides which school: the one of the signed-in user.
class ApiInstitutionRepository implements InstitutionRepository {
  final ApiClient _api;

  const ApiInstitutionRepository(this._api);

  @override
  Future<InstitutionModel> getInstitution() async => InstitutionModel.fromJson(
    await _api.get('/institution') as Map<String, dynamic>,
  );

  @override
  Future<AcademicYearModel> getCurrentAcademicYear() async =>
      AcademicYearModel.fromJson(
        await _api.get('/academic-year') as Map<String, dynamic>,
      );

  @override
  Future<void> updateInstitution(InstitutionModel institution) =>
      _api.patch('/institution', institution.toJson());

  @override
  Future<void> updateWorkingDays(List<int> workingDays) =>
      _api.patch('/academic-year', {'workingDays': workingDays});

  @override
  Future<void> addHoliday(HolidayModel holiday) =>
      _api.post('/academic-year/holidays', holiday.toJson());

  @override
  Future<void> updateHoliday(HolidayModel old, HolidayModel updated) async {
    final id = old.id;
    if (id == null) {
      throw ApiException(tr('This holiday was not saved yet.'));
    }
    await _api.patch('/academic-year/holidays/$id', updated.toJson());
  }

  @override
  Future<void> removeHoliday(HolidayModel holiday) async {
    final id = holiday.id;
    if (id == null) {
      throw ApiException(tr('This holiday was not saved yet.'));
    }
    await _api.delete('/academic-year/holidays/$id');
  }
}
