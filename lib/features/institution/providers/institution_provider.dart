import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';

import '../models/academic_year_model.dart';
import '../models/holiday_model.dart';
import '../models/institution_model.dart';
import '../repo/api_institution_repository.dart';
import '../repo/institution_repository.dart';
import '../repo/mock_institution_repository.dart';

/// The server when API_URL is set, otherwise the mock school.
final institutionRepositoryProvider = Provider<InstitutionRepository>(
  (ref) => AppConfig.useApi
      ? ApiInstitutionRepository(watchApi(ref))
      : MockInstitutionRepository(),
);

/// Reloads when another user signs in (they may be in another school).
final institutionProvider = FutureProvider<InstitutionModel>((ref) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(institutionRepositoryProvider).getInstitution();
});

final academicYearProvider = FutureProvider<AcademicYearModel>((ref) {
  ref.watch(authProvider.select((user) => user?.id));
  return ref.watch(institutionRepositoryProvider).getCurrentAcademicYear();
});

/// Administrator actions. Each one saves, then reloads what depends on it.
final institutionActionsProvider = Provider<InstitutionActions>(
  InstitutionActions.new,
);

class InstitutionActions {
  final Ref _ref;

  InstitutionActions(this._ref);

  InstitutionRepository get _repository =>
      _ref.read(institutionRepositoryProvider);

  Future<void> updateInstitution(InstitutionModel institution) async {
    await _repository.updateInstitution(institution);
    _ref.invalidate(institutionProvider);
  }

  Future<void> updateWorkingDays(List<int> workingDays) async {
    await _repository.updateWorkingDays(workingDays);
    _ref.invalidate(academicYearProvider);
  }

  Future<void> addHoliday(HolidayModel holiday) async {
    await _repository.addHoliday(holiday);
    _ref.invalidate(academicYearProvider);
  }

  Future<void> updateHoliday(HolidayModel old, HolidayModel updated) async {
    await _repository.updateHoliday(old, updated);
    _ref.invalidate(academicYearProvider);
  }

  Future<void> removeHoliday(HolidayModel holiday) async {
    await _repository.removeHoliday(holiday);
    _ref.invalidate(academicYearProvider);
  }
}
