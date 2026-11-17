import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

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

class PlanTipModel {
  final String id;
  final PlanWhen when;
  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  final int priority;

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

List<PlanTipModel> sortTips(Iterable<PlanTipModel> tips) {
  return tips.toList()..sort((a, b) {
    final byWhen = a.when.index.compareTo(b.when.index);
    return byWhen != 0 ? byWhen : b.priority.compareTo(a.priority);
  });
}
