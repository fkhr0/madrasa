import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../models/subject_model.dart';

/// Fake subjects used until the backend is connected.
class MockSubjects {
  MockSubjects._();

  static const math = SubjectModel(
    id: 'math',
    name: 'Mathematics',
    teacherName: 'Mr. Ahmed Kareem',
    icon: Icons.functions,
    color: AppColors.subjectPurple,
  );

  static const physics = SubjectModel(
    id: 'physics',
    name: 'Physics',
    teacherName: 'Ms. Sara Hadi',
    icon: Icons.bolt_outlined,
    color: AppColors.subjectBlue,
  );

  static const chemistry = SubjectModel(
    id: 'chemistry',
    name: 'Chemistry',
    teacherName: 'Mr. Omar Saleh',
    icon: Icons.science_outlined,
    color: AppColors.subjectTeal,
  );

  static const arabic = SubjectModel(
    id: 'arabic',
    name: 'Arabic Language',
    teacherName: 'Ms. Huda Jaber',
    icon: Icons.menu_book_outlined,
    color: AppColors.subjectOrange,
  );

  static const english = SubjectModel(
    id: 'english',
    name: 'English',
    teacherName: 'Ms. Rana Sami',
    icon: Icons.translate,
    color: AppColors.subjectPink,
  );

  static const islamic = SubjectModel(
    id: 'islamic',
    name: 'Islamic Education',
    teacherName: 'Mr. Yusuf Ali',
    icon: Icons.auto_stories_outlined,
    color: AppColors.subjectAmber,
  );

  static const biology = SubjectModel(
    id: 'biology',
    name: 'Biology',
    teacherName: 'Ms. Noor Abbas',
    icon: Icons.eco_outlined,
    color: AppColors.subjectGreen,
  );

  static const computer = SubjectModel(
    id: 'computer',
    name: 'Computer Science',
    teacherName: 'Mr. Bilal Nasser',
    icon: Icons.computer_outlined,
    color: AppColors.neutral,
  );

  static const all = [
    math,
    physics,
    chemistry,
    arabic,
    english,
    islamic,
    biology,
    computer,
  ];
}
