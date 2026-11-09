import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/language.dart';

/// Who an announcement was sent to.
enum AnnouncementAudience {
  school,
  className,
  parents,
  teachers;

  String get label {
    switch (this) {
      case AnnouncementAudience.school:
        return tr('Whole school');
      case AnnouncementAudience.className:
        return tr('Class');
      case AnnouncementAudience.parents:
        return tr('Parents');
      case AnnouncementAudience.teachers:
        return tr('Teachers');
    }
  }

  Color get color {
    switch (this) {
      case AnnouncementAudience.school:
        return AppColors.info;
      case AnnouncementAudience.className:
        return AppColors.subjectGreen;
      case AnnouncementAudience.parents:
        return AppColors.subjectOrange;
      case AnnouncementAudience.teachers:
        return AppColors.subjectPurple;
    }
  }

  /// The name the server uses ("class" for [className]).
  String get apiName => this == className ? 'class' : name;

  static AnnouncementAudience fromApiName(String value) =>
      value == 'class' ? className : AnnouncementAudience.values.byName(value);

  IconData get icon {
    switch (this) {
      case AnnouncementAudience.school:
        return Icons.campaign_outlined;
      case AnnouncementAudience.className:
        return Icons.groups_outlined;
      case AnnouncementAudience.parents:
        return Icons.family_restroom;
      case AnnouncementAudience.teachers:
        return Icons.co_present_outlined;
    }
  }
}

class AnnouncementModel {
  final String id;
  final String title;
  final String body;
  final String authorName;

  /// The account that wrote it; null for old mock announcements.
  final String? authorId;
  final AnnouncementAudience audience;

  /// The class name when [audience] is a class.
  final String? className;
  final DateTime publishedAt;

  /// Pinned announcements stay at the top of the list.
  final bool isPinned;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
    this.authorId,
    required this.audience,
    this.className,
    required this.publishedAt,
    this.isPinned = false,
  });

  AnnouncementModel copyWith({
    String? title,
    String? body,
    AnnouncementAudience? audience,
    String? className,
    DateTime? publishedAt,
    bool? isPinned,
  }) {
    return AnnouncementModel(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      authorName: authorName,
      authorId: authorId,
      audience: audience ?? this.audience,
      className: (audience ?? this.audience) == AnnouncementAudience.className
          ? className ?? this.className
          : null,
      publishedAt: publishedAt ?? this.publishedAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      authorName: json['authorName'] as String,
      authorId: json['authorId'] as String?,
      audience: AnnouncementAudience.fromApiName(json['audience'] as String),
      className: json['className'] as String?,
      publishedAt: DateTime.parse(json['publishedAt'] as String).toLocal(),
      isPinned: json['isPinned'] as bool? ?? false,
    );
  }

  /// What the server needs to publish or edit it. The server fills in the
  /// author; [publishedAt] is sent only when it is in the future (scheduled).
  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'audience': audience.apiName,
    'className': className,
    'isPinned': isPinned,
    if (publishedAt.isAfter(DateTime.now()))
      'publishedAt': publishedAt.toUtc().toIso8601String(),
  };

  /// Whether [userId] wrote it ([name] for announcements without an author ID).
  bool isWrittenBy(String userId, String name) =>
      authorId == null ? authorName == name : authorId == userId;

  /// "Whole school", "5th Scientific – A", "Parents"...
  String get audienceLabel => className ?? audience.label;
}
