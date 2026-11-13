import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../schedule/models/lesson_model.dart';
import '../models/day_status.dart';
import '../providers/today_provider.dart';
import '../../../core/l10n/language.dart';

/// The hero card of every home page.
class DayStatusCard extends ConsumerWidget {
  final String? who;

  const DayStatusCard({super.key, this.who});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(dayStatusProvider).valueOrNull;
    final now = ref.watch(nowProvider);
    if (status == null) return const SizedBox(height: 150);

    final content = _contentFor(status, now);

    return Material(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: context.palette.hero,
          ),
        ),
        child: InkWell(
          onTap: () => context.push(AppRoutes.day),
          child: Stack(
            children: [
              const Positioned(right: -30, top: -40, child: _Circle(130)),
              const Positioned(right: 50, bottom: -50, child: _Circle(90)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: _CardBody(
                  label: who == null
                      ? content.label
                      : '$who · ${content.label}',
                  content: content,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Turns the status into the words shown on the card.
  static _CardContent _contentFor(DayStatus status, DateTime now) {
    switch (status) {
      case BeforeSchool(:final firstLesson, :final lessonCount):
        return _CardContent(
          icon: Icons.wb_sunny_outlined,
          label: tr('Today · {0} classes', [lessonCount]),
          title: tr('Starts at {0}', [DateFormatter.time(firstLesson.start)]),
          lines: ['First: ${_describe(firstLesson)}'],
        );

      case InClass(
        :final lesson,
        :final nextLesson,
        :final period,
        :final lessonCount,
      ):
        final left = lesson.end.difference(now).inMinutes + 1;
        return _CardContent(
          icon: Icons.play_circle_outline,
          label: tr('Now · period {0} of {1}', [period, lessonCount]),
          title: _title(lesson),
          lines: [
            '${DateFormatter.time(lesson.start)} – '
                '${DateFormatter.time(lesson.end)} · ${lesson.room}',
            nextLesson == null
                ? tr('Last class today')
                : tr('Next: {0} at {1}', [
                    _title(nextLesson),
                    DateFormatter.time(nextLesson.start),
                  ]),
          ],
          progress:
              now.difference(lesson.start).inMinutes / lesson.durationMinutes,
          progressLabel: tr('{0} min left', [left]),
        );

      case BetweenClasses(:final nextLesson, :final lessonsLeft):
        final minutes = nextLesson.start.difference(now).inMinutes + 1;
        return _CardContent(
          icon: Icons.coffee_outlined,
          label: minutes >= 10 ? tr('Break') : tr('Next class'),
          title: _title(nextLesson),
          lines: [
            tr('Starts at {0} · in {1} min', [
              DateFormatter.time(nextLesson.start),
              minutes,
            ]),
            lessonsLeft == 1
                ? tr('1 class left today')
                : tr('{0} classes left today', [lessonsLeft]),
          ],
        );

      case SchoolOver(:final next, :final hadClassesToday):
        return _CardContent(
          icon: Icons.nights_stay_outlined,
          label: hadClassesToday
              ? tr('Done for today')
              : tr('No classes today'),
          title: next == null
              ? tr('That was the last school day')
              : tr('{0} at a glance', [DateFormatter.relativeDay(next.date)]),
          lines: _upcomingLines(next),
        );

      case DayOff(:final holiday, :final next):
        return _CardContent(
          icon: holiday?.type.icon ?? Icons.weekend_outlined,
          label: holiday == null ? tr('Weekend') : tr('Holiday'),
          title: holiday?.name ?? tr('Enjoy your weekend'),
          lines: next == null
              ? const []
              : [
                  tr('Back on {0}', [_dayName(next.date)]),
                  ..._upcomingLines(next),
                ],
        );

      case OutsideYear(:final notStartedYet, :final yearStart):
        return _CardContent(
          icon: Icons.school_outlined,
          label: tr('School year'),
          title: notStartedYet
              ? tr('Starts on {0}', [DateFormatter.fullDate(yearStart)])
              : tr('The school year has ended'),
          lines: const [],
        );
    }
  }

  /// "6 classes · first: Mathematics at 08:00".
  static List<String> _upcomingLines(UpcomingDay? next) {
    final first = next?.firstLesson;
    if (next == null || first == null) return const [];

    return [
      tr('{0} classes · first: {1} at {2}', [
        next.lessons.length,
        _title(first),
        DateFormatter.time(first.start),
      ]),
    ];
  }

  static String _dayName(DateTime date) {
    final relative = DateFormatter.relativeDay(date);
    return relative == tr('Tomorrow')
        ? 'tomorrow'
        : DateFormatter.weekday(date);
  }

  /// Teachers see the class, students and parents the subject.
  static String _title(LessonModel lesson) =>
      lesson.className ?? lesson.subject.name;

  static String _describe(LessonModel lesson) =>
      '${_title(lesson)} · ${lesson.room}';
}

/// What the card shows, decided by [DayStatusCard._contentFor].
class _CardContent {
  final IconData icon;
  final String label;
  final String title;
  final List<String> lines;

  /// 0–1 while a class is running.
  final double? progress;
  final String? progressLabel;

  const _CardContent({
    required this.icon,
    required this.label,
    required this.title,
    required this.lines,
    this.progress,
    this.progressLabel,
  });
}

class _CardBody extends StatelessWidget {
  final String label;
  final _CardContent content;

  const _CardBody({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    final soft = Colors.white.withValues(alpha: 0.8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(content.icon, size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  style: context.text.labelSmall?.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          content.title,
          style: context.text.headlineSmall?.copyWith(color: Colors.white),
        ),
        for (final (i, line) in content.lines.indexed) ...[
          SizedBox(height: i == 0 ? AppSpacing.sm : 2),
          Text(
            line,
            style: (i == 0 ? context.text.bodyMedium : context.text.bodySmall)
                ?.copyWith(color: i == 0 ? Colors.white : soft),
          ),
        ],
        if (content.progress != null) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: content.progress!.clamp(0, 1),
                    minHeight: 5,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                content.progressLabel ?? '',
                style: context.text.labelSmall?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;

  const _Circle(this.size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
