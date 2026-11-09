import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

/// When a tip matters. The planner page groups tips by this.
enum PlanWhen {
  today,
  tomorrow,
  thisWeek;

  String get label {
    switch (this) {
      case PlanWhen.today:
        return tr('Today');
      case PlanWhen.tomorrow:
        return tr('Tomorrow');
      case PlanWhen.thisWeek:
        return tr('This week');
    }
  }
}

/// One suggestion from the planner, e.g. "Exam tomorrow: Physics".
class PlanTipModel {
  final String id;
  final PlanWhen when;
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  /// Higher shows first (0–100).
  final int priority;

  /// Where tapping the tip leads.
  final String? route;

  const PlanTipModel({
    required this.id,
    required this.when,
    required this.icon,
    required this.color,
    required this.title,
    this.detail,
    required this.priority,
    this.route,
  });
}

/// Today first, then by priority.
List<PlanTipModel> sortTips(Iterable<PlanTipModel> tips) {
  return tips.toList()..sort((a, b) {
    final byWhen = a.when.index.compareTo(b.when.index);
    return byWhen != 0 ? byWhen : b.priority.compareTo(a.priority);
  });
}
