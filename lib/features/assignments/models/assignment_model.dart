import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../academics/models/subject_style.dart';
import '../../subjects/models/subject_model.dart';
import 'attachment_model.dart';
import '../../../core/l10n/language.dart';

enum AssignmentType {
  homework,
  assignment,
  project,
  quiz;

  String get label {
    switch (this) {
      case AssignmentType.homework:
        return tr('Homework');
      case AssignmentType.assignment:
        return tr('Assignment');
      case AssignmentType.project:
        return tr('Project');
      case AssignmentType.quiz:
        return tr('Quiz');
    }
  }
}

enum AssignmentStatus {
  pending,
  submitted,
  graded;

  String get label {
    switch (this) {
      case AssignmentStatus.pending:
        return tr('To do');
      case AssignmentStatus.submitted:
        return tr('Submitted');
      case AssignmentStatus.graded:
        return tr('Graded');
    }
  }

  Color get color {
    switch (this) {
      case AssignmentStatus.pending:
        return AppColors.warning;
      case AssignmentStatus.submitted:
        return AppColors.info;
      case AssignmentStatus.graded:
        return AppColors.success;
    }
  }
}

class AssignmentModel {
  final String id;
  final String title;
  final SubjectModel subject;
  final AssignmentType type;
  final String description;
  final DateTime assignedAt;
  final DateTime dueDate;
  final AssignmentStatus status;

  /// Files from the teacher.
  final List<AttachmentModel> attachments;

  /// Files the student handed in.
  final List<AttachmentModel> submittedFiles;
  final DateTime? submittedAt;

  /// Whether the teacher accepts work after the due date.
  final bool allowsLateSubmission;

  final double? grade;
  final double? maxGrade;
  final String? feedback;

  /// Students must hand in a file (otherwise "Mark as done").
  final bool acceptsFiles;

  /// Set by the server.
  final String classId;
  final String className;

  /// Staff lists: how many handed in, and how many are graded.
  final int submittedCount;
  final int gradedCount;

  const AssignmentModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.description,
    required this.assignedAt,
    required this.dueDate,
    required this.status,
    this.attachments = const [],
    this.submittedFiles = const [],
    this.submittedAt,
    this.allowsLateSubmission = false,
    this.grade,
    this.maxGrade,
    this.feedback,
    this.acceptsFiles = true,
    this.classId = '',
    this.className = '',
    this.submittedCount = 0,
    this.gradedCount = 0,
  });

  /// One assignment from the server, with the student's submission if any.
  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    final submission = json['submission'] as Map<String, dynamic>?;
    final grade = (submission?['grade'] as num?)?.toDouble();
    final submittedAt = submission?['submittedAt'] as String?;

    return AssignmentModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: SubjectModel(
        id: json['subjectId'] as String,
        name: json['subjectName'] as String,
        teacherName: json['teacherName'] as String? ?? '',
        icon: SubjectStyle.icon(json['icon'] as String? ?? 'book'),
        color: SubjectStyle.color(json['color'] as String? ?? 'blue'),
      ),
      type: AssignmentType.values.byName(json['type'] as String),
      description: json['description'] as String? ?? '',
      assignedAt: DateTime.parse(json['assignedAt'] as String).toLocal(),
      dueDate: DateTime.parse(json['dueAt'] as String).toLocal(),
      status: grade != null
          ? AssignmentStatus.graded
          : submittedAt != null
          ? AssignmentStatus.submitted
          : AssignmentStatus.pending,
      attachments: _files(json['attachments']),
      submittedFiles: _files(submission?['files']),
      submittedAt: submittedAt == null
          ? null
          : DateTime.parse(submittedAt).toLocal(),
      allowsLateSubmission: json['allowsLate'] as bool? ?? false,
      grade: grade,
      maxGrade: (json['maxGrade'] as num).toDouble(),
      feedback: submission?['feedback'] as String?,
      acceptsFiles: json['acceptsFiles'] as bool? ?? true,
      classId: json['classId'] as String? ?? '',
      className: json['className'] as String? ?? '',
      submittedCount: json['submittedCount'] as int? ?? 0,
      gradedCount: json['gradedCount'] as int? ?? 0,
    );
  }

  static List<AttachmentModel> _files(Object? list) => [
    for (final f in list as List? ?? const [])
      AttachmentModel.fromJson(f as Map<String, dynamic>),
  ];

  bool get isOverdue =>
      status == AssignmentStatus.pending && DateTime.now().isAfter(dueDate);

  bool get canSubmit =>
      status == AssignmentStatus.pending &&
      (!isOverdue || allowsLateSubmission);

  AssignmentModel copyWith({
    AssignmentStatus? status,
    List<AttachmentModel>? submittedFiles,
    DateTime? submittedAt,
  }) {
    return AssignmentModel(
      id: id,
      title: title,
      subject: subject,
      type: type,
      description: description,
      assignedAt: assignedAt,
      dueDate: dueDate,
      status: status ?? this.status,
      attachments: attachments,
      submittedFiles: submittedFiles ?? this.submittedFiles,
      submittedAt: submittedAt ?? this.submittedAt,
      allowsLateSubmission: allowsLateSubmission,
      grade: grade,
      maxGrade: maxGrade,
      feedback: feedback,
      acceptsFiles: acceptsFiles,
      classId: classId,
      className: className,
      submittedCount: submittedCount,
      gradedCount: gradedCount,
    );
  }
}

/// What a teacher or the office fills in to set work for a class.
class AssignmentDraftModel {
  final String classId;
  final String subjectId;
  final String title;
  final AssignmentType type;
  final String description;
  final DateTime dueDate;
  final bool allowsLateSubmission;
  final bool acceptsFiles;
  final double maxGrade;

  /// The teacher's files (already uploaded).
  final List<AttachmentModel> attachments;

  const AssignmentDraftModel({
    required this.classId,
    required this.subjectId,
    required this.title,
    required this.type,
    required this.description,
    required this.dueDate,
    required this.allowsLateSubmission,
    required this.acceptsFiles,
    this.maxGrade = 10,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() => {
    'subjectId': subjectId,
    'type': type.name,
    'title': title,
    'description': description,
    'dueAt': dueDate.toUtc().toIso8601String(),
    'allowsLate': allowsLateSubmission,
    'acceptsFiles': acceptsFiles,
    'maxGrade': maxGrade,
    'fileIds': [for (final f in attachments) f.id],
  };
}

/// A student on a teacher's hand-in list.
class StudentSubmissionModel {
  final String id;
  final String name;
  final DateTime? submittedAt;
  final List<AttachmentModel> files;
  final double? grade;
  final String? feedback;

  const StudentSubmissionModel({
    required this.id,
    required this.name,
    this.submittedAt,
    this.files = const [],
    this.grade,
    this.feedback,
  });

  bool get handedIn => submittedAt != null;

  factory StudentSubmissionModel.fromJson(Map<String, dynamic> json) {
    final sub = json['submission'] as Map<String, dynamic>?;
    final submittedAt = sub?['submittedAt'] as String?;

    return StudentSubmissionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      submittedAt: submittedAt == null
          ? null
          : DateTime.parse(submittedAt).toLocal(),
      files: AssignmentModel._files(sub?['files']),
      grade: (sub?['grade'] as num?)?.toDouble(),
      feedback: sub?['feedback'] as String?,
    );
  }
}
