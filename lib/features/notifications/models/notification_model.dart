import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum NotificationType {
  assignment,
  grade,
  announcement,
  message,
  schedule,
  attendance,
  transport,
  reminder,
  payment,

  /// The office's daily summary, a parent's weekly one.
  summary;

  IconData get icon {
    switch (this) {
      case NotificationType.assignment:
        return Icons.assignment_outlined;
      case NotificationType.grade:
        return Icons.grade_outlined;
      case NotificationType.announcement:
        return Icons.campaign_outlined;
      case NotificationType.message:
        return Icons.chat_bubble_outline;
      case NotificationType.schedule:
        return Icons.event_repeat_outlined;
      case NotificationType.attendance:
        return Icons.fact_check_outlined;
      case NotificationType.transport:
        return Icons.directions_bus_outlined;
      case NotificationType.reminder:
        return Icons.alarm;
      case NotificationType.payment:
        return Icons.payments_outlined;
      case NotificationType.summary:
        return Icons.insights_outlined;
    }
  }

  Color get color {
    switch (this) {
      case NotificationType.assignment:
        return AppColors.warning;
      case NotificationType.grade:
        return AppColors.success;
      case NotificationType.announcement:
        return AppColors.info;
      case NotificationType.message:
        return AppColors.subjectPurple;
      case NotificationType.schedule:
        return AppColors.subjectTeal;
      case NotificationType.attendance:
        return AppColors.subjectOrange;
      case NotificationType.transport:
        return AppColors.subjectAmber;
      case NotificationType.reminder:
        return AppColors.subjectPink;
      case NotificationType.payment:
        return AppColors.success;
      case NotificationType.summary:
        return AppColors.info;
    }
  }
}

class NotificationModel {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Where tapping the notification leads, e.g. "/assignments/a1".
  final String? route;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.route,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return NotificationModel(
      id: json['id'] as String,
      type:
          NotificationType.values.where((t) => t.name == type).firstOrNull ??
          NotificationType.announcement,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      isRead: json['isRead'] as bool? ?? false,
      route: json['route'] as String?,
    );
  }

  NotificationModel markedRead() => NotificationModel(
    id: id,
    type: type,
    title: title,
    body: body,
    createdAt: createdAt,
    isRead: true,
    route: route,
  );
}
