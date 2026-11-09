import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/l10n/language.dart';
import '../../../core/utils/day_json.dart';

/// What an activity line is about (server: activity_log.kind).
enum ActivityKind {
  attendance('Attendance', Icons.fact_check_outlined, AppColors.subjectTeal),
  grades('Exams & grades', Icons.grade_outlined, AppColors.success),
  homework('Homework', Icons.assignment_outlined, AppColors.subjectBlue),
  announcement('Announcements', Icons.campaign_outlined, AppColors.info),
  people('Accounts', Icons.person_outline, AppColors.subjectPurple),
  academics(
    'Classes & timetable',
    Icons.school_outlined,
    AppColors.subjectOrange,
  ),
  finance('Fees', Icons.payments_outlined, AppColors.subjectAmber),
  transport('Bus', Icons.directions_bus_outlined, AppColors.subjectPink),
  material('Study material', Icons.menu_book_outlined, AppColors.neutral);

  final String _label;
  final IconData icon;
  final Color color;

  const ActivityKind(this._label, this.icon, this.color);

  String get label => tr(_label);

  static ActivityKind fromName(String name) =>
      values.where((k) => k.name == name).firstOrNull ?? announcement;
}

/// One line of who did what, and when.
class ActivityItemModel {
  final String id;
  final DateTime at;
  final String actorName;

  /// "teacher", "admin"...
  final String actorRole;
  final ActivityKind kind;

  /// e.g. "attendance.taken".
  final String action;

  /// "Ahmed Kareem took attendance for 5th A, period 2 ..."
  final String summary;
  final String? className;

  /// Where tapping it leads, if anywhere.
  final String? route;

  const ActivityItemModel({
    required this.id,
    required this.at,
    required this.actorName,
    required this.actorRole,
    required this.kind,
    required this.action,
    required this.summary,
    this.className,
    this.route,
  });

  factory ActivityItemModel.fromJson(Map<String, dynamic> json) =>
      ActivityItemModel(
        id: json['id'] as String,
        at: DateTime.parse(json['at'] as String).toLocal(),
        actorName: json['actorName'] as String? ?? '',
        actorRole: json['actorRole'] as String? ?? '',
        kind: ActivityKind.fromName(json['kind'] as String),
        action: json['action'] as String? ?? '',
        summary: json['summary'] as String,
        className: json['className'] as String?,
        route: json['route'] as String?,
      );
}

/// Which lines to show. All fields optional; equal filters share a list.
class ActivityFilter {
  /// One day, or a range with [from] / [to].
  final DateTime? date;
  final DateTime? from;
  final DateTime? to;

  /// Empty = every kind.
  final Set<ActivityKind> kinds;
  final String? actorId;
  final String? classId;
  final String? studentId;
  final String query;

  const ActivityFilter({
    this.date,
    this.from,
    this.to,
    this.kinds = const {},
    this.actorId,
    this.classId,
    this.studentId,
    this.query = '',
  });

  bool get isEmpty =>
      date == null &&
      from == null &&
      to == null &&
      kinds.isEmpty &&
      actorId == null &&
      classId == null &&
      studentId == null &&
      query.isEmpty;

  ActivityFilter copyWith({
    DateTime? Function()? date,
    DateTime? Function()? from,
    DateTime? Function()? to,
    Set<ActivityKind>? kinds,
    String? Function()? actorId,
    String? Function()? classId,
    String? query,
  }) => ActivityFilter(
    date: date == null ? this.date : date(),
    from: from == null ? this.from : from(),
    to: to == null ? this.to : to(),
    kinds: kinds ?? this.kinds,
    actorId: actorId == null ? this.actorId : actorId(),
    classId: classId == null ? this.classId : classId(),
    studentId: studentId,
    query: query ?? this.query,
  );

  /// The server's query string (without "before" and "limit").
  Map<String, String> toQuery() => {
    if (date != null) 'date': formatDay(date!),
    if (from != null) 'from': formatDay(from!),
    if (to != null) 'to': formatDay(to!),
    if (kinds.isNotEmpty) 'kind': kinds.map((k) => k.name).join(','),
    'actorId': ?actorId,
    'classId': ?classId,
    'studentId': ?studentId,
    if (query.trim().isNotEmpty) 'q': query.trim(),
  };

  @override
  bool operator ==(Object other) =>
      other is ActivityFilter &&
      other.date == date &&
      other.from == from &&
      other.to == to &&
      other.kinds.length == kinds.length &&
      other.kinds.containsAll(kinds) &&
      other.actorId == actorId &&
      other.classId == classId &&
      other.studentId == studentId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(
    date,
    from,
    to,
    Object.hashAllUnordered(kinds),
    actorId,
    classId,
    studentId,
    query,
  );
}

/// A page of lines; [next] is passed back to load older ones.
class ActivityPageModel {
  final List<ActivityItemModel> items;
  final DateTime? next;

  const ActivityPageModel({required this.items, this.next});
}
