import 'package:flutter/material.dart';

import '../../../core/utils/grade_scale.dart';
import '../../subjects/models/subject_model.dart';
import 'grade_item_model.dart';

class SubjectGradesModel {
  final SubjectModel subject;
  final List<GradeItemModel> items;

  const SubjectGradesModel({required this.subject, required this.items});

  bool get hasMarks => items.isNotEmpty;

  double get average {
    if (items.isEmpty) return 0;

    final scored = items.fold<double>(0, (sum, i) => sum + i.score);
    final possible = items.fold<double>(0, (sum, i) => sum + i.maxScore);

    return scored / possible * 100;
  }

  Color get color => GradeScale.colorFor(average);

  String get label => GradeScale.labelFor(average);
}
