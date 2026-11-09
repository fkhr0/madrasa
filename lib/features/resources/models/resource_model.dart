import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../academics/models/subject_style.dart';
import '../../assignments/models/attachment_model.dart';
import '../../subjects/models/subject_model.dart';
import '../../../core/l10n/language.dart';

enum ResourceType {
  pdf,
  slides,
  video,
  link;

  String get label {
    switch (this) {
      case ResourceType.pdf:
        return tr('PDF');
      case ResourceType.slides:
        return tr('Slides');
      case ResourceType.video:
        return tr('Video');
      case ResourceType.link:
        return tr('Link');
    }
  }

  IconData get icon {
    switch (this) {
      case ResourceType.pdf:
        return Icons.picture_as_pdf_outlined;
      case ResourceType.slides:
        return Icons.slideshow_outlined;
      case ResourceType.video:
        return Icons.play_circle_outline;
      case ResourceType.link:
        return Icons.link;
    }
  }

  Color get color {
    switch (this) {
      case ResourceType.pdf:
        return AppColors.danger;
      case ResourceType.slides:
        return AppColors.warning;
      case ResourceType.video:
        return AppColors.subjectPurple;
      case ResourceType.link:
        return AppColors.info;
    }
  }
}

/// Study material shared by a teacher.
class ResourceModel {
  final String id;
  final String title;
  final SubjectModel subject;
  final ResourceType type;
  final DateTime uploadedAt;

  /// "2.4 MB" for files, "12 min" for videos, null for links.
  final String? detail;

  /// The shared file (server), or null for a link / mock data.
  final AttachmentModel? file;

  /// The web address of a link or video.
  final String? url;

  final String classId;

  const ResourceModel({
    required this.id,
    required this.title,
    required this.subject,
    required this.type,
    required this.uploadedAt,
    this.detail,
    this.file,
    this.url,
    this.classId = '',
  });

  factory ResourceModel.fromJson(Map<String, dynamic> json) {
    final fileId = json['fileId'] as String?;
    final file = fileId == null
        ? null
        : AttachmentModel.fromJson({
            'id': fileId,
            'name': json['fileName'] as String,
            'size': json['fileSize'] as int? ?? 0,
          });

    return ResourceModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: SubjectModel(
        id: json['subjectId'] as String,
        name: json['subjectName'] as String,
        teacherName: '',
        icon: SubjectStyle.icon(json['icon'] as String? ?? 'book'),
        color: SubjectStyle.color(json['color'] as String? ?? 'blue'),
      ),
      type: ResourceType.values.byName(json['type'] as String),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String).toLocal(),
      detail: file?.size,
      file: file,
      url: json['url'] as String?,
      classId: json['classId'] as String? ?? '',
    );
  }
}
