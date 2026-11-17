import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/clock_provider.dart';
import '../../institution/providers/institution_provider.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../logic/day_status_resolver.dart';
import '../models/day_status.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

final nextSchoolDayProvider = FutureProvider<UpcomingDay?>((ref) async {
  final today = _dateOnly(ref.watch(nowProvider));
  final year = await ref.watch(academicYearProvider.future);

  final candidate = year.nextSchoolDay(today.add(const Duration(days: 1)));
  if (!candidate.isAfter(today) || !year.isSchoolDay(candidate)) return null;

  final lessons = await ref.watch(lessonsForDayProvider(candidate).future);
  return UpcomingDay(date: candidate, lessons: lessons);
});

final dayStatusProvider = FutureProvider<DayStatus>((ref) async {
  final now = ref.watch(nowProvider);
  final year = await ref.watch(academicYearProvider.future);
  final todayLessons = await ref.watch(
    lessonsForDayProvider(_dateOnly(now)).future,
  );
  final next = await ref.watch(nextSchoolDayProvider.future);

  return resolveDayStatus(
    now: now,
    year: year,
    todayLessons: todayLessons,
    next: next,
  );
});
