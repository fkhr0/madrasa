import 'package:flutter/material.dart';

class SubjectModel {
  final String id;
  final String name;
  final String teacherName;
  final IconData icon;

  final Color color;

  const SubjectModel({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.icon,
    required this.color,
  });
}
