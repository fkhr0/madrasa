import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../academics/providers/academics_provider.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../people/providers/people_provider.dart';
import '../../teaching/providers/teaching_provider.dart';
import '../models/activity_item_model.dart';
import '../providers/activity_provider.dart';
import '../widgets/activity_tile.dart';
import '../../../core/l10n/language.dart';

/// Every record of who did what, newest first, with filters: when, what kind,
/// and (office, teachers) which class, who, and words to search.
class ActivityPage extends ConsumerStatefulWidget {
  /// Opens on this day (e.g. from a day's page).
  final DateTime? date;

  const ActivityPage({super.key, this.date});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends ConsumerState<ActivityPage> {
  late ActivityFilter _filter = ActivityFilter(date: widget.date);
  final _search = TextEditingController();

  /// The person picked in the "who" filter, to show their name.
  String? _actorName;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(ActivityFilter filter) => setState(() => _filter = filter);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// "Today", "Yesterday", "This week", a picked day, or any time.
  Future<void> _pickWhen() async {
    final today = _day(DateTime.now());
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (key, label) in [
              ('any', tr('Any time')),
              ('today', tr('Today')),
              ('yesterday', tr('Yesterday')),
              ('week', tr('Last 7 days')),
              ('pick', tr('Choose a day…')),
            ])
              ListTile(
                title: Text(label),
                onTap: () => Navigator.pop(sheet, key),
              ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    switch (choice) {
      case 'any':
        _set(
          _filter.copyWith(date: () => null, from: () => null, to: () => null),
        );
      case 'today':
        _set(
          _filter.copyWith(date: () => today, from: () => null, to: () => null),
        );
      case 'yesterday':
        _set(
          _filter.copyWith(
            date: () => today.subtract(const Duration(days: 1)),
            from: () => null,
            to: () => null,
          ),
        );
      case 'week':
        _set(
          _filter.copyWith(
            date: () => null,
            from: () => today.subtract(const Duration(days: 6)),
            to: () => today,
          ),
        );
      case 'pick':
        final picked = await showDatePicker(
          context: context,
          initialDate: _filter.date ?? today,
          firstDate: DateTime(today.year - 2),
          lastDate: today,
        );
        if (picked != null) {
          _set(
            _filter.copyWith(
              date: () => picked,
              from: () => null,
              to: () => null,
            ),
          );
        }
    }
  }

  String get _whenLabel {
    if (_filter.date case final d?) return DateFormatter.relativeDay(d);
    if (_filter.from != null) return tr('Last 7 days');
    return tr('Any time');
  }

  Future<void> _pickClass(List<(String, String)> classes) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(tr('Every class')),
              onTap: () => Navigator.pop(sheet, ''),
            ),
            for (final (id, name) in classes)
              ListTile(
                title: Text(name),
                onTap: () => Navigator.pop(sheet, id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    _set(_filter.copyWith(classId: () => picked.isEmpty ? null : picked));
  }

  /// Office: anyone at the school (staff first: they do most things).
  Future<void> _pickPerson() async {
    final picked = await showModalBottomSheet<UserModel?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _PersonSheet(),
    );
    if (!mounted) return;
    if (picked == null) {
      // Closed without choosing: keep the filter. "Anyone" returns a marker.
      return;
    }
    setState(() {
      _actorName = picked.id.isEmpty ? null : picked.name;
      _filter = _filter.copyWith(
        actorId: () => picked.id.isEmpty ? null : picked.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentUserProvider).role;
    final isOffice = role == UserRole.admin;
    final isTeacher = role == UserRole.teacher;
    final List<(String, String)> classes = isOffice
        ? [
            for (final c in ref.watch(schoolClassesProvider).valueOrNull ?? [])
              (c.id, c.name),
          ]
        : isTeacher
        ? [
            for (final c in ref.watch(myClassesProvider).valueOrNull ?? [])
              (c.id, c.name),
          ]
        : const <(String, String)>[];
    final className = classes
        .where((c) => c.$1 == _filter.classId)
        .map((c) => c.$2)
        .firstOrNull;
    final feed = ref.watch(activityFeedProvider(_filter));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Activity'))),
      body: Column(
        children: [
          // ---------- Filters ----------
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              0,
            ),
            child: Row(
              children: [
                _FilterChip(
                  icon: Icons.event_outlined,
                  label: _whenLabel,
                  active: _filter.date != null || _filter.from != null,
                  onTap: _pickWhen,
                ),
                if (classes.isNotEmpty)
                  _FilterChip(
                    icon: Icons.class_outlined,
                    label: className ?? tr('Every class'),
                    active: className != null,
                    onTap: () => _pickClass(classes),
                  ),
                if (isOffice)
                  _FilterChip(
                    icon: Icons.person_search_outlined,
                    label: _actorName ?? tr('Anyone'),
                    active: _actorName != null,
                    onTap: _pickPerson,
                  ),
                if (!_filter.isEmpty)
                  TextButton(
                    onPressed: () {
                      _search.clear();
                      setState(() {
                        _actorName = null;
                        _filter = const ActivityFilter();
                      });
                    },
                    child: Text(tr('Clear')),
                  ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                for (final kind in ActivityKind.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: FilterChip(
                      avatar: Icon(kind.icon, size: 16, color: kind.color),
                      label: Text(kind.label),
                      selected: _filter.kinds.contains(kind),
                      onSelected: (on) => _set(
                        _filter.copyWith(
                          kinds: on
                              ? {..._filter.kinds, kind}
                              : ({..._filter.kinds}..remove(kind)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOffice || isTeacher)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (q) => _set(_filter.copyWith(query: q)),
                decoration: InputDecoration(
                  hintText: tr('Search, e.g. a name or "absent"'),
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: tr('Search'),
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () =>
                        _set(_filter.copyWith(query: _search.text)),
                  ),
                ),
              ),
            ),

          // ---------- The records ----------
          Expanded(
            child: AsyncValueView(
              value: feed,
              onRetry: () => ref.invalidate(activityFeedProvider(_filter)),
              data: (state) {
                if (state.items.isEmpty) {
                  return EmptyState(
                    icon: Icons.history,
                    title: tr('Nothing here'),
                    message: tr('Try another day or fewer filters.'),
                  );
                }
                return NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 400) {
                      ref
                          .read(activityFeedProvider(_filter).notifier)
                          .loadMore();
                    }
                    return false;
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.xs,
                      AppSpacing.page,
                      AppSpacing.xl,
                    ),
                    children: [
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, item) in state.items.indexed) ...[
                              if (i > 0)
                                const Divider(
                                  indent: AppSpacing.lg,
                                  endIndent: AppSpacing.lg,
                                ),
                              ActivityTile(item: item),
                            ],
                          ],
                        ),
                      ),
                      if (state.next != null)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.lg),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
      child: InputChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: active,
        onPressed: onTap,
        showCheckmark: false,
      ),
    );
  }
}

/// Picks a person at the school: role chips, then a name.
class _PersonSheet extends ConsumerStatefulWidget {
  const _PersonSheet();

  @override
  ConsumerState<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends ConsumerState<_PersonSheet> {
  UserRole _role = UserRole.teacher;

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleByRoleProvider(_role));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                Expanded(
                  child: Text(tr('Who'), style: context.text.titleLarge),
                ),
                TextButton(
                  // An empty ID = everyone.
                  onPressed: () => Navigator.pop(
                    context,
                    const UserModel(
                      id: '',
                      name: '',
                      role: UserRole.admin,
                      email: '',
                      phone: '',
                      schoolName: '',
                    ),
                  ),
                  child: Text(tr('Anyone')),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Row(
              children: [
                for (final role in UserRole.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.xs,
                    ),
                    child: ChoiceChip(
                      label: Text(role.label),
                      selected: _role == role,
                      onSelected: (_) => setState(() => _role = role),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: people,
              data: (list) => ListView(
                children: [
                  for (final person in list)
                    ListTile(
                      title: Text(person.name),
                      subtitle: Text(person.id),
                      onTap: () => Navigator.pop(context, person),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
