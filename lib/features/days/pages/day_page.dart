import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/icon_box.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_badge.dart';
import '../../activity/models/activity_item_model.dart';
import '../../activity/providers/activity_provider.dart';
import '../../activity/widgets/activity_tile.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/active_student_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/day_model.dart';
import '../providers/day_provider.dart';
import '../widgets/period_card.dart';
import '../../../core/l10n/language.dart';

/// A day at school, for any date, as the signed-in person needs it: office
/// the whole school: totals, what's on now, every period and whether its
/// attendance was taken (by whom, when) teacher  their lessons with attendance,
/// homework due, exams student  their lessons with their own marks, homework,
/// exams, bus parent   the same for the selected child Then "What happened"
/// that day, from the activity log.
class DayPage extends ConsumerStatefulWidget {
  final DateTime? date;

  const DayPage({super.key, this.date});

  @override
  ConsumerState<DayPage> createState() => _DayPageState();
}

class _DayPageState extends ConsumerState<DayPage> {
  late DateTime _date = _dateOnly(widget.date ?? DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _move(int days) =>
      setState(() => _date = _date.add(Duration(days: days)));

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final (view, studentId) = switch (user.role) {
      UserRole.admin => (DayView.school, null),
      UserRole.teacher => (DayView.teacher, null),
      UserRole.student => (DayView.student, user.id),
      UserRole.parent => (DayView.student, ref.watch(activeStudentIdProvider)),
      // Drivers: only what they did (their trips are in the activity).
      UserRole.driver => (null, null),
    };
    final day = view == null
        ? null
        : ref.watch(dayProvider((view, studentId, _date)));
    final title = switch (view) {
      DayView.school => tr('School day'),
      DayView.teacher || null => tr('My day'),
      DayView.student =>
        user.role == UserRole.parent
            ? "${day?.valueOrNull?.studentName?.split(' ').first ?? 'Your child'}'s day"
            : tr('My day'),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              IconButton(
                tooltip: tr('Day before'),
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _pick,
                  child: Text(
                    '${DateFormatter.relativeDay(_date)} · '
                    '${DateFormatter.fullDate(_date)}',
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Day after'),
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (view != null) {
            ref.invalidate(dayProvider((view, studentId, _date)));
          }
          ref.invalidate(activityFeedProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            if (day != null)
              AsyncValueView(
                value: day,
                onRetry: () =>
                    ref.invalidate(dayProvider((view!, studentId, _date))),
                data: (day) => _DayBody(day: day, view: view!),
              ),
            const SizedBox(height: AppSpacing.xl),
            _WhatHappened(
              filter: ActivityFilter(
                date: _date,
                studentId: user.role == UserRole.parent ? studentId : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBody extends StatelessWidget {
  final DayModel day;
  final DayView view;

  const _DayBody({required this.day, required this.view});

  @override
  Widget build(BuildContext context) {
    if (!day.isSchoolDay) {
      return EmptyState(
        icon: Icons.weekend_outlined,
        title: tr('No school'),
        message: day.dayOff,
      );
    }

    void openLesson(DayLessonModel lesson) =>
        context.push(AppRoutes.takeAttendance(lesson.classId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view == DayView.school && day.totals != null) ...[
          _Totals(totals: day.totals!),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (view == DayView.student && day.dayStatus != null) ...[
          AppCard(
            child: Row(
              children: [
                IconBox(icon: day.dayStatus!.icon, color: day.dayStatus!.color),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    day.dayNote ?? tr('The whole day'),
                    style: context.text.bodyMedium,
                  ),
                ),
                StatusBadge(
                  label: day.dayStatus!.label,
                  color: day.dayStatus!.color,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SectionHeader(
          title: switch (view) {
            DayView.school => tr('Lessons and attendance'),
            DayView.teacher => tr('My lessons'),
            DayView.student => tr('Lessons'),
          },
        ),
        if (day.periods.isEmpty)
          Text(
            view == DayView.teacher
                ? tr('You have no lessons this day.')
                : tr('No lessons this day.'),
            style: context.text.bodyMedium,
          ),
        for (final period in day.periods) ...[
          PeriodCard(
            period: period,
            ownMarks: view == DayView.student,
            onLessonTap: view == DayView.student ? null : openLesson,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (day.homework.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: tr('Homework due')),
          _Items(items: day.homework, icon: Icons.assignment_outlined),
        ],
        if (day.exams.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: tr('Exams')),
          _Items(items: day.exams, icon: Icons.edit_note),
        ],
        if (day.bus.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: tr('Bus')),
          for (final trip in day.bus)
            AppCard(
              child: Row(
                children: [
                  const IconBox(
                    icon: Icons.directions_bus_outlined,
                    color: AppColors.subjectAmber,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      tr('{0} · bus {1}\n{2} – {3}', [
                        trip.toSchool ? tr('To school') : tr('Trip home'),
                        trip.busNumber,
                        DateFormatter.time(trip.startedAt),
                        trip.endedAt == null
                            ? tr('on the way')
                            : DateFormatter.time(trip.endedAt!),
                      ]),
                      style: context.text.bodyMedium,
                    ),
                  ),
                  if (trip.boarded)
                    StatusBadge(
                      label: tr('On board'),
                      color: AppColors.success,
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// The office's numbers for the day, in two rows of tiles.
class _Totals extends StatelessWidget {
  final DayTotalsModel totals;

  const _Totals({required this.totals});

  @override
  Widget build(BuildContext context) {
    final rate = totals.present + totals.absent == 0
        ? null
        : (totals.present / (totals.present + totals.absent) * 100).round();

    Widget tile(String value, String label, {Color? color}) => Expanded(
      child: Column(
        children: [
          Text(value, style: context.text.titleLarge?.copyWith(color: color)),
          Text(
            label,
            style: context.text.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              tile(rate == null ? '–' : '$rate%', tr('present')),
              tile(
                '${totals.absent}',
                tr('absent'),
                color: totals.absent > 0 ? AppColors.warning : null,
              ),
              tile('${totals.excused}', tr('excused')),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            children: [
              tile(
                '${totals.lessonsTaken}/${totals.lessons}',
                tr('lessons taken'),
              ),
              tile(
                '${totals.lessonsMissing}',
                tr('missing'),
                color: totals.lessonsMissing > 0
                    ? AppColors.danger
                    : AppColors.success,
              ),
              tile(
                totals.moneyReceived == 0
                    ? '0'
                    : MoneyFormatter.compact(totals.moneyReceived),
                tr('IQD received'),
              ),
            ],
          ),
          if (totals.homeworkDue > 0 || totals.exams > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('{0} homework due · {1} exams', [
                totals.homeworkDue,
                totals.exams,
              ]),
              style: context.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Items extends StatelessWidget {
  final List<DayItemModel> items;
  final IconData icon;

  const _Items({required this.items, required this.icon});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              leading: Icon(icon, color: context.palette.primary),
              title: Text(item.title),
              subtitle: Text(
                [
                  item.detail,
                  if (item.status != null) item.status!,
                ].join(' · '),
              ),
            ),
        ],
      ),
    );
  }
}

/// The day's activity (the first lines; "See all" opens the full list).
class _WhatHappened extends ConsumerWidget {
  final ActivityFilter filter;

  const _WhatHappened({required this.filter});

  static const _shown = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(activityFeedProvider(filter));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: tr('What happened'),
          onSeeAll: () => context.push(AppRoutes.activityOn(filter.date!)),
        ),
        AsyncValueView(
          value: feed,
          onRetry: () => ref.invalidate(activityFeedProvider(filter)),
          data: (state) => state.items.isEmpty
              ? Text(
                  tr('Nothing recorded this day.'),
                  style: context.text.bodyMedium,
                )
              : AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, item)
                          in state.items.take(_shown).indexed) ...[
                        if (i > 0)
                          const Divider(
                            indent: AppSpacing.lg,
                            endIndent: AppSpacing.lg,
                          ),
                        ActivityTile(item: item, showDay: false),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
