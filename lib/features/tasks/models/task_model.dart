import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/language.dart';

enum TaskPriority {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case TaskPriority.low:
        return tr('Low');
      case TaskPriority.medium:
        return tr('Medium');
      case TaskPriority.high:
        return tr('High');
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return AppColors.info;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.high:
        return AppColors.danger;
    }
  }
}

enum TaskRepeat {
  none,
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case TaskRepeat.none:
        return tr('Does not repeat');
      case TaskRepeat.daily:
        return tr('Every day');
      case TaskRepeat.weekly:
        return tr('Every week');
      case TaskRepeat.monthly:
        return tr('Every month');
    }
  }
}

/// A personal task or reminder the student creates for themselves.
/// A reminder is a task that alerts the student at [dueAt].
class TaskModel {
  final String id;
  final String title;
  final String? note;
  final DateTime dueAt;
  final TaskPriority priority;
  final TaskRepeat repeat;
  final bool isDone;
  final bool isReminder;

  /// Where the reminder leads, e.g. the assignment it is about.
  final String? route;

  const TaskModel({
    required this.id,
    required this.title,
    required this.dueAt,
    this.note,
    this.priority = TaskPriority.medium,
    this.repeat = TaskRepeat.none,
    this.isDone = false,
    this.isReminder = false,
    this.route,
  });

  bool get isOverdue => !isDone && DateTime.now().isAfter(dueAt);

  factory TaskModel.fromJson(Map<String, dynamic> json) => TaskModel(
    id: json['id'] as String,
    title: json['title'] as String,
    note: json['note'] as String?,
    dueAt: DateTime.parse(json['dueAt'] as String).toLocal(),
    priority: TaskPriority.values.byName(json['priority'] as String),
    repeat: TaskRepeat.values.byName(json['repeat'] as String),
    isDone: json['isDone'] as bool? ?? false,
    isReminder: json['isReminder'] as bool? ?? false,
    route: json['route'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'dueAt': dueAt.toUtc().toIso8601String(),
    'priority': priority.name,
    'repeat': repeat.name,
    'isDone': isDone,
    'isReminder': isReminder,
    'route': route,
  };

  TaskModel copyWith({bool? isDone}) {
    return TaskModel(
      id: id,
      title: title,
      note: note,
      dueAt: dueAt,
      priority: priority,
      repeat: repeat,
      isDone: isDone ?? this.isDone,
      isReminder: isReminder,
      route: route,
    );
  }
}
