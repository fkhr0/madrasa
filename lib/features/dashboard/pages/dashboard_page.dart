import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../announcements/providers/announcement_provider.dart';
import '../../assignments/providers/assignment_provider.dart';
import '../../attendance/providers/attendance_provider.dart';
import '../../exams/providers/exam_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../planner/widgets/for_you_section.dart';
import '../../schedule/providers/schedule_provider.dart';
import '../../today/widgets/day_status_card.dart';
import '../../transport/widgets/bus_mini_card.dart';
import '../widgets/greeting_header.dart';
import '../widgets/latest_announcements_section.dart';
import '../widgets/quick_access_row.dart';
import '../widgets/today_overview.dart';

/// Student's 10–30 second screen. Every block reacts to the moment:
/// the day card follows the timetable, the bus card appears only around
/// trip time, and "For you" lists what matters next.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(todayLessonsProvider)
      ..invalidate(assignmentsProvider)
      ..invalidate(examsProvider)
      ..invalidate(announcementsProvider)
      ..invalidate(attendanceRecordsProvider)
      ..invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            children: const [
              GreetingHeader(),
              SizedBox(height: AppSpacing.xl),
              DayStatusCard(),
              SizedBox(height: AppSpacing.md),
              BusMiniCard(),
              TodayOverview(),
              SizedBox(height: AppSpacing.lg),
              QuickAccessRow(),
              SizedBox(height: AppSpacing.lg),
              ForYouSection(),
              SizedBox(height: AppSpacing.lg),
              LatestAnnouncementsSection(),
            ],
          ),
        ),
      ),
    );
  }
}
