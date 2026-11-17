import '../../auth/models/user_model.dart';

class NewAccountModel {
  final UserRole role;
  final String name;
  final String email;
  final String phone;

  final String? className;

  final String? subjectName;

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
