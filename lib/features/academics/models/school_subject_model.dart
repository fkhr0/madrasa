import 'package:flutter/material.dart';

import 'subject_style.dart';

/// A subject in the school's catalogue, managed by the administrator.
class SchoolSubjectModel {
  /// Empty for a subject not saved yet.
  final String id;
  final String name;

  /// Keys from [SubjectStyle], e.g. "math" and "purple".
  final String iconKey;
  final String colorKey;

  /// How many classes study it.
  final int classCount;

  const SchoolSubjectModel({
    required this.id,
    required this.name,
    this.iconKey = 'book',
    this.colorKey = 'blue',
    this.classCount = 0,
  });

  IconData get icon => SubjectStyle.icon(iconKey);

  Color get color => SubjectStyle.color(colorKey);

  factory SchoolSubjectModel.fromJson(Map<String, dynamic> json) =>
      SchoolSubjectModel(
        id: json['id'] as String,
        name: json['name'] as String,
        iconKey: json['icon'] as String? ?? 'book',
        colorKey: json['color'] as String? ?? 'blue',
        classCount: json['classCount'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'icon': iconKey,
    'color': colorKey,
  };

  SchoolSubjectModel copyWith({
    String? id,
    String? name,
    String? iconKey,
    String? colorKey,
    int? classCount,
  }) {
    return SchoolSubjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorKey: colorKey ?? this.colorKey,
      classCount: classCount ?? this.classCount,
    );
  }
}
