import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/providers/clock_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/progress_bar_row.dart';
import '../../../core/widgets/section_header.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../models/finance_summary_model.dart';
import '../models/student_account_model.dart';
import '../providers/finance_provider.dart';
import '../widgets/account_tile.dart';
import '../widgets/payment_tile.dart';
import '../../../core/l10n/language.dart';

/// Administrator: the year's fees, collected, outstanding, who is behind,
/// and each family's account.
class FinancePage extends ConsumerWidget {
  const FinancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(financeSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Finance')),
        actions: [
          IconButton(
            tooltip: tr('Fees and installments'),
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(AppRoutes.feeSettings),
          ),
        ],
      ),
      body: AsyncValueView(
        value: summary,
        onRetry: () => ref.invalidate(accountsProvider),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.xl,
          ),
          children: [
            _CollectedCard(summary: summary),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.warning_amber,
                    color: AppColors.danger,
                    value: '${summary.overdueFamilies}',
                    label: tr('Overdue'),
                    onTap: () =>
                        ref.read(accountFilterProvider.notifier).state =
                            AccountStatus.overdue,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.verified_outlined,
                    color: AppColors.success,
                    value: '${summary.paidInFullCount}',
                    label: tr('Paid in full'),
                    onTap: () =>
                        ref.read(accountFilterProvider.notifier).state =
                            AccountStatus.paidInFull,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: StatTile(
                    icon: Icons.calendar_month_outlined,
                    color: AppColors.info,
                    value: MoneyFormatter.compact(summary.collectedThisMonth),
                    label: tr('This month'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('Collection by class')),
            AppCard(
              child: Column(
                children: [
                  for (final c in summary.byClass)
                    ProgressBarRow(
                      label: c.className,
                      value: '${(c.rate * 100).round()}%',
                      fraction: c.rate,
                      color: c.rate < 0.4
                          ? AppColors.danger
                          : c.rate < 0.7
                          ? AppColors.warning
                          : AppColors.success,
                    ),
                ],
              ),
            ),
            if (summary.recentPayments.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              SectionHeader(title: tr('Recent payments')),
              _RecentPayments(summary: summary),
            ],
            const SizedBox(height: AppSpacing.xl),
            SectionHeader(title: tr('Accounts')),
            const _AccountsList(),
          ],
        ),
      ),
    );
  }
}

class _CollectedCard extends StatelessWidget {
  final FinanceSummaryModel summary;

  const _CollectedCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const onHero = Colors.white;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: palette.hero,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Collected this year'),
              style: context.text.labelLarge?.copyWith(
                color: onHero.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                MoneyFormatter.iqd(summary.collected),
                style: context.text.headlineMedium?.copyWith(color: onHero),
              ),
            ),
            Text(
              tr('of {0} · {1}%', [
                MoneyFormatter.iqd(summary.expected),
                (summary.collectionRate * 100).round(),
              ]),
              style: context.text.bodySmall?.copyWith(
                color: onHero.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.collectionRate,
                minHeight: 8,
                color: onHero,
                backgroundColor: onHero.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              tr('Outstanding {0} · overdue {1}', [
                MoneyFormatter.iqd(summary.outstanding),
                MoneyFormatter.iqd(summary.overdueAmount),
              ]),
              style: context.text.bodySmall?.copyWith(color: onHero),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentPayments extends ConsumerWidget {
  final FinanceSummaryModel summary;

  const _RecentPayments({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    String nameOf(String id) => accounts
        .firstWhere((a) => a.studentId == id, orElse: () => accounts.first)
        .studentName;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: Column(
        children: [
          for (final p in summary.recentPayments)
            PaymentTile(payment: p, title: nameOf(p.studentId)),
        ],
      ),
    );
  }
}

class _AccountsList extends ConsumerWidget {
  const _AccountsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(filteredAccountsProvider);
    final filter = ref.watch(accountFilterProvider);
    final DateTime now = ref.watch(nowProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => ref.read(accountSearchProvider.notifier).state = v,
          decoration: InputDecoration(
            hintText: tr('Search by name, class or ID'),
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in [null, ...AccountStatus.values])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(option?.label ?? tr('All')),
                    selected: filter == option,
                    onSelected: (_) =>
                        ref.read(accountFilterProvider.notifier).state = option,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (accounts.isEmpty)
          EmptyState(icon: Icons.search_off, title: tr('No accounts match'))
        else
          for (final a in accounts) ...[
            AccountTile(account: a, now: now),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}
