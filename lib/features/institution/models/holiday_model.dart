import 'package:flutter/material.dart';

import '../../../core/utils/day_json.dart';

enum HolidayType {
  schoolBreak,

  national,

  religious;

  IconData get icon {
    switch (this) {
      case HolidayType.schoolBreak:
        return Icons.beach_access_outlined;
      case HolidayType.national:
        return Icons.flag_outlined;
      case HolidayType.religious:
        return Icons.nights_stay_outlined;
    }
  }
}

class HolidayModel {
  final String? id;
  final String name;
  final HolidayType type;
  final DateTime start;

  final DateTime? end;

  final bool isOfficial;

  const HolidayModel({
    this.id,
    required this.name,
    required this.type,
    required this.start,
    this.end,
    this.isOfficial = false,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    final end = json['end'] as String?;
    return HolidayModel(
      id: json['id'] as String?,
      name: json['name'] as String,
      type: HolidayType.values.byName(json['type'] as String),
      start: parseDay(json['start'] as String),
      end: end == null ? null : parseDay(end),
      isOfficial: json['isOfficial'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.name,
    'start': formatDay(start),
    'end': end == null ? null : formatDay(end!),
  };

  DateTime get lastDay => end ?? start;

  bool includes(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return !date.isBefore(start) && !date.isAfter(lastDay);
  }

  int get lengthInDays => lastDay.difference(start).inDays + 1;
}
