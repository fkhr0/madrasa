import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:latlong2/latlong.dart';

import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/context_extensions.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/models/user_model.dart';
import '../../people/providers/people_provider.dart';
import '../models/bus_route_model.dart';
import '../models/bus_stop_model.dart';
import '../models/route_student_model.dart';
import '../logic/stop_planning.dart';
import '../providers/transport_provider.dart';
import '../repo/transport_repository.dart';
import '../widgets/home_location_sheet.dart';
import '../../../core/l10n/language.dart';

/// Administrator: who rides a line, stop by stop.
/// Add students who have no bus, move them to another stop, or remove them.
class RouteStudentsPage extends ConsumerWidget {
  final String routeId;

  const RouteStudentsPage({super.key, required this.routeId});

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    BusRouteModel route,
  ) async {
    if (route.isFull) {
      context.showMessage(tr('Bus {0} is full', [route.busNumber]));
      return;
    }

    final student = await showModalBottomSheet<UserModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _StudentPickerSheet(),
    );
    if (student == null || !context.mounted) return;

    var stop = await _pickStop(context, route, title: student.firstName);
    if (stop == null || !context.mounted) return;
    if (stop == _atHome) {
      stop = await _homeStop(
        context,
        ref,
        route,
        student.id,
        student.firstName,
      );
      if (stop == null || !context.mounted) return;
    }

    // Link the student's parent, if the school has one on file.
    final parents =
        ref.read(peopleByRoleProvider(UserRole.parent)).valueOrNull ?? [];
    UserModel? parent;
    for (final p in parents) {
      if (p.children.any((c) => c.id == student.id)) parent = p;
    }

    try {
      await ref
          .read(transportActionsProvider)
          .saveRouteStudent(
            route.id,
            RouteStudentModel(
              id: student.id,
              name: student.name,
              stopId: stop.id,
              className: student.className ?? '',
              parentId: parent?.id ?? '',
              parentName: parent?.name ?? tr('No parent linked'),
              parentPhone: parent?.phone ?? '',
            ),
          );
      if (context.mounted) {
        context.showMessage(
          tr('{0} rides from {1}', [student.firstName, stop.name]),
        );
      }
    } on TransportException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    BusRouteModel route,
    RouteStudentModel student,
  ) async {
    final firstName = student.name.split(' ').first;
    var stop = await _pickStop(
      context,
      route,
      title: firstName,
      current: student.stopId,
    );
    if (stop == null || !context.mounted) return;
    if (stop == _atHome) {
      stop = await _homeStop(context, ref, route, student.id, firstName);
      if (stop == null || !context.mounted) return;
    }
    if (stop.id == student.stopId) return;

    await ref
        .read(transportActionsProvider)
        .saveRouteStudent(route.id, student.copyWith(stopId: stop.id));
  }

  /// Chosen in the stop list: pick the student up at their door.
  static const _atHome = BusStopModel(
    id: '_at_home',
    name: '',
    landmark: '',
    latitude: 0,
    longitude: 0,
    morningMinute: 0,
    afternoonMinute: 0,
  );

  /// The stop at the student's home: asks where it is, then adds it to the
  /// line where it adds the least driving (the road is redrawn on save).
  /// A brother or sister already picked up at that door shares their stop.
  Future<BusStopModel?> _homeStop(
    BuildContext context,
    WidgetRef ref,
    BusRouteModel route,
    String studentId,
    String firstName,
  ) async {
    final home = await showHomeLocationSheet(
      context,
      studentId: studentId,
      firstName: firstName,
    );
    if (home == null) return null;
    final p = home.point;

    const distance = Distance();
    for (final s in route.pickUpStops) {
      if (distance(LatLng(s.latitude, s.longitude), p) < 40) return s;
    }

    final stops = [...route.stops];
    final index = bestInsertIndex(stops, p.latitude, p.longitude);
    final (morning, afternoon) = suggestedTimes(stops, index);
    stops.insert(
      index,
      BusStopModel(
        id: '${BusStopModel.newIdPrefix}home-$studentId',
        name: '$firstName${BusStopModel.homeSuffix}',
        landmark: home.note.isEmpty ? tr('Door to door') : home.note,
        latitude: p.latitude,
        longitude: p.longitude,
        morningMinute: morning,
        afternoonMinute: afternoon,
      ),
    );

    try {
      final saved = await ref
          .read(transportActionsProvider)
          .saveRoute(route.copyWith(stops: stops));
      // The saved copy has the server's ID for the new stop.
      return saved.stops.firstWhere(
        (s) =>
            (s.latitude - p.latitude).abs() < 1e-6 &&
            (s.longitude - p.longitude).abs() < 1e-6,
      );
    } on TransportException catch (e) {
      if (context.mounted) context.showMessage(e.message);
      return null;
    }
  }

  Future<BusStopModel?> _pickStop(
    BuildContext context,
    BusRouteModel route, {
    required String title,
    String? current,
  }) {
    return showModalBottomSheet<BusStopModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Text(
                tr('Where does {0} get on?', [title]),
                style: context.text.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: Text(tr('At home (door to door)')),
              subtitle: Text(tr('From the location the family sent')),
              onTap: () => Navigator.pop(context, _atHome),
            ),
            if (route.pickUpStops.isNotEmpty) const Divider(),
            for (final stop in route.pickUpStops)
              ListTile(
                leading: Icon(
                  stop.id == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(stop.name),
                subtitle: Text(stop.landmark),
                onTap: () => Navigator.pop(context, stop),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(busRouteProvider(routeId)).valueOrNull;
    final students = ref.watch(routeStudentsProvider(routeId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          route == null
              ? tr('Riders')
              : tr('Riders · {0}/{1}', [route.studentCount, route.capacity]),
        ),
      ),
      floatingActionButton: route == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _add(context, ref, route),
              icon: const Icon(Icons.person_add_alt),
              label: Text(tr('Add rider')),
            ),
      body: AsyncValueView(
        value: students,
        data: (students) {
          if (route == null) return const SizedBox.shrink();
          if (students.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: tr('No riders yet'),
              message: tr('Add the students who take this bus.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.sm,
              AppSpacing.page,
              96,
            ),
            children: [
              for (final stop in route.pickUpStops) ...[
                SectionHeader(title: stop.name),
                ..._ridersAt(stop, students).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _RiderTile(
                      student: s,
                      onMove: () => _move(context, ref, route, s),
                      onRemove: () async {
                        final sure = await confirmDelete(
                          context,
                          title: tr('Take {0} off bus {1}?', [
                            s.name,
                            route.busNumber,
                          ]),
                          message: tr(
                            'They and their parent will no longer see this bus.',
                          ),
                          action: tr('Remove'),
                        );
                        if (!sure) return;
                        final actions = ref.read(transportActionsProvider);
                        await actions.removeRouteStudent(route.id, s.id);

                        // Nobody else gets on at that door: the bus no
                        // longer needs to go there.
                        final stop = route.stops
                            .where((x) => x.id == s.stopId)
                            .firstOrNull;
                        final othersThere = students.any(
                          (x) => x.id != s.id && x.stopId == s.stopId,
                        );
                        if (stop != null && stop.isHome && !othersThere) {
                          await actions.saveRoute(
                            route.copyWith(
                              stops: [
                                for (final x in route.stops)
                                  if (x.id != stop.id) x,
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
                if (_ridersAt(stop, students).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      tr('Nobody gets on here yet'),
                      style: context.text.bodySmall,
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static List<RouteStudentModel> _ridersAt(
    BusStopModel stop,
    List<RouteStudentModel> students,
  ) => students.where((s) => s.stopId == stop.id).toList();
}

class _RiderTile extends StatelessWidget {
  final RouteStudentModel student;
  final VoidCallback onMove;
  final VoidCallback onRemove;

  const _RiderTile({
    required this.student,
    required this.onMove,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.md,
        AppSpacing.sm,
        0,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          UserAvatar(name: student.name, size: 36),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: context.text.titleSmall),
                Text(
                  '${student.className} · ${student.parentName}',
                  style: context.text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (_) => [
              PopupMenuItem(value: onMove, child: Text(tr('Change stop'))),
              PopupMenuItem(
                value: onRemove,
                child: Text(
                  tr('Remove from bus'),
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Students with no bus, with a search box.
class _StudentPickerSheet extends ConsumerStatefulWidget {
  const _StudentPickerSheet();

  @override
  ConsumerState<_StudentPickerSheet> createState() =>
      _StudentPickerSheetState();
}

class _StudentPickerSheetState extends ConsumerState<_StudentPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(studentsWithoutBusProvider).valueOrNull ?? [];
    final q = _query.trim().toLowerCase();
    final shown = students
        .where(
          (s) =>
              q.isEmpty ||
              s.name.toLowerCase().contains(q) ||
              (s.className?.toLowerCase().contains(q) ?? false),
        )
        .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: tr('Search students without a bus'),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? EmptyState(
                    icon: Icons.check_circle_outline,
                    title: tr('Everyone has a bus'),
                    message: tr('Or nobody matches the search.'),
                  )
                : ListView(
                    children: [
                      for (final s in shown)
                        ListTile(
                          leading: UserAvatar(name: s.name, size: 36),
                          title: Text(s.name),
                          subtitle: Text(s.className ?? ''),
                          onTap: () => Navigator.pop(context, s),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
