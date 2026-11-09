import 'package:flutter/material.dart';

/// A school subject. Shared by schedule, assignments and grades.
class SubjectModel {
  final String id;
  final String name;
  final String teacherName;
  final IconData icon;

  /// Muted accent from AppColors.subject*.
  final Color color;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.icon,
    required this.color,
  });
}
