import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../l10n/language.dart';

/// The Iraqi grading scale (out of 100, pass mark 50):
/// 90+ Excellent (امتياز) · 80+ Very good (جيد جداً) · 70+ Good (جيد)
/// 60+ Average (متوسط) · 50+ Pass (مقبول) · below 50 Fail (راسب)
class GradeScale {
  GradeScale._();

  static const passMark = 50.0;

  static String labelFor(double percentage) {
    if (percentage >= 90) return tr('Excellent');
    if (percentage >= 80) return tr('Very good');
    if (percentage >= 70) return tr('Good');
    if (percentage >= 60) return tr('Average');
    if (percentage >= passMark) return tr('Pass');

    return tr('Fail');
  }

  static Color colorFor(double percentage) {
    if (percentage >= 80) return AppColors.success;
    if (percentage >= 60) return AppColors.info;
    if (percentage >= passMark) return AppColors.warning;

    return AppColors.danger;
  }
}
