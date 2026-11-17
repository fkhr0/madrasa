import '../../../core/l10n/language.dart';

enum UserRole {
  student,
  teacher,
  parent,
  admin,
  driver;

  String get label {
    switch (this) {
      case UserRole.student:
        return tr('Student');
      case UserRole.teacher:
        return tr('Teacher');
      case UserRole.parent:
        return tr('Parent');
      case UserRole.admin:
        return tr('Administrator');
      case UserRole.driver:
        return tr('Bus driver');
    }
  }

  String get pluralLabel => switch (this) {
    UserRole.student => tr('Students'),
    UserRole.teacher => tr('Teachers'),
    UserRole.parent => tr('Parents'),
    UserRole.admin => tr('Administrators'),
    UserRole.driver => tr('Bus drivers'),
  };

  static UserRole fromName(String name) =>
      values.firstWhere((r) => r.name == name, orElse: () => student);

  String get idPrefix {
    switch (this) {
      case UserRole.student:
        return 'STU';
      case UserRole.teacher:
        return 'TCH';
      case UserRole.parent:
        return 'PAR';
      case UserRole.admin:
        return 'ADM';
      case UserRole.driver:
        return 'DRV';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final UserRole role;
  final String email;
  final String phone;
  final String schoolName;

  final String? className;

  final String? subjectName;

  final List<UserModel> children;

  final bool isActive;

  final bool mustChangePassword;

  final bool isDemo;

  const UserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    required this.schoolName,
    this.className,
    this.subjectName,
    this.children = const [],
    this.isActive = true,
    this.mustChangePassword = false,
    this.isDemo = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      role: UserRole.fromName(json['role'] as String),
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      schoolName: json['schoolName'] as String? ?? '',
      className: json['className'] as String?,
      subjectName: json['subjectName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      isDemo: json['isDemo'] as bool? ?? false,
      children: [
        for (final child in json['children'] as List? ?? const [])
          UserModel.fromJson(child as Map<String, dynamic>),
      ],
    );
  }

  String get firstName => name.split(' ').first;

  String get roleDetail {
    switch (role) {
      case UserRole.student:
        return className ?? role.label;
      case UserRole.teacher:
        return tr('{0} teacher', [subjectName ?? '']).trim();
      case UserRole.parent:
        return tr('Parent of {0}', [
          children.map((c) => c.firstName).join(' and '),
        ]);
      case UserRole.admin:
        return tr('School administration');
      case UserRole.driver:
        return tr('School bus driver');
    }
  }

  String get idPrefix => role.idPrefix;

  UserModel copyWith({
    String? email,
    String? phone,
    bool? isActive,
    bool? mustChangePassword,
  }) {
    return UserModel(
      id: id,
      name: name,
      role: role,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      schoolName: schoolName,
      className: className,
      subjectName: subjectName,
      children: children,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      isDemo: isDemo,
    );
  }
}
