import '../../auth/models/user_model.dart';

/// What the administrator fills in to create an account.
/// The ID and the first password are generated, not typed.
class NewAccountModel {
  final UserRole role;
  final String name;
  final String email;
  final String phone;

  /// Students only.
  final String? className;

  /// Teachers only.
  final String? subjectName;

  /// Parents only: IDs of the children to link.
  final List<String> childIds;

  const NewAccountModel({
    required this.role,
    required this.name,
    required this.email,
    required this.phone,
    this.className,
    this.subjectName,
    this.childIds = const [],
  });
}
