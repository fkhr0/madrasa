import 'package:flutter/material.dart';

import 'subject_style.dart';

class SchoolSubjectModel {
  final String id;
  final String name;

  final String iconKey;
  final String colorKey;

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
