import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// The icons and colours a subject can have. The server stores the key
/// ("math", "purple"); the app turns it into an icon and a colour.
class SubjectStyle {
  SubjectStyle._();

  static const icons = <String, IconData>{
    'book': Icons.menu_book_outlined,
    'math': Icons.functions,
    'physics': Icons.bolt_outlined,
    'chemistry': Icons.science_outlined,
    'biology': Icons.eco_outlined,
    'language': Icons.auto_stories_outlined,
    'english': Icons.translate,
    'islamic': Icons.mosque_outlined,
    'computer': Icons.computer_outlined,
    'history': Icons.history_edu_outlined,
    'geography': Icons.public,
    'art': Icons.palette_outlined,
    'sport': Icons.sports_soccer_outlined,
  };

  static const colors = <String, Color>{
    'blue': AppColors.subjectBlue,
    'teal': AppColors.subjectTeal,
    'green': AppColors.subjectGreen,
    'orange': AppColors.subjectOrange,
    'purple': AppColors.subjectPurple,
    'pink': AppColors.subjectPink,
    'amber': AppColors.subjectAmber,
    'gray': AppColors.neutral,
  };

  static IconData icon(String key) => icons[key] ?? Icons.menu_book_outlined;

  static Color color(String key) => colors[key] ?? AppColors.subjectBlue;
}
