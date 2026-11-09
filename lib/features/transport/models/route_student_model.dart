import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/language.dart';

/// A student registered on a bus route, as the driver sees them.
class RouteStudentModel {
  final String id;
  final String name;
  final String stopId;
  final String className;
  final String parentId;
  final String parentName;
  final String parentPhone;

  /// The parent said the child won't ride today.
  final bool notRidingToday;

  const RouteStudentModel({
    required this.id,
    required this.name,
    required this.stopId,
    required this.className,
    required this.parentId,
    required this.parentName,
    required this.parentPhone,
    this.notRidingToday = false,
  });

  factory RouteStudentModel.fromJson(Map<String, dynamic> json) {
    return RouteStudentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      stopId: json['stopId'] as String,
      className: json['className'] as String? ?? '',
      parentId: json['parentId'] as String? ?? '',
      parentName: json['parentName'] as String? ?? '',
      parentPhone: json['parentPhone'] as String? ?? '',
      notRidingToday: json['notRidingToday'] as bool? ?? false,
    );
  }

  RouteStudentModel copyWith({String? stopId, bool? notRidingToday}) {
    return RouteStudentModel(
      id: id,
      name: name,
      stopId: stopId ?? this.stopId,
      className: className,
      parentId: parentId,
      parentName: parentName,
      parentPhone: parentPhone,
      notRidingToday: notRidingToday ?? this.notRidingToday,
    );
  }
}

/// Where a student is on today's trip.
enum BoardingStatus {
  waiting,
  onBoard,
  droppedOff,
  absent,
  notRiding;

  String get label {
    switch (this) {
      case BoardingStatus.waiting:
        return tr('Waiting');
      case BoardingStatus.onBoard:
        return tr('On the bus');
      case BoardingStatus.droppedOff:
        return tr('Dropped off');
      case BoardingStatus.absent:
        return tr('Absent');
      case BoardingStatus.notRiding:
        return tr('Not riding today');
    }
  }

  Color get color {
    switch (this) {
      case BoardingStatus.waiting:
        return AppColors.neutral;
      case BoardingStatus.onBoard:
        return AppColors.success;
      case BoardingStatus.droppedOff:
        return AppColors.info;
      case BoardingStatus.absent:
        return AppColors.danger;
      case BoardingStatus.notRiding:
        return AppColors.warning;
    }
  }
}
