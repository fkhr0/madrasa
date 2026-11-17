import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_provider.dart';
import '../../auth/providers/auth_provider.dart';

import '../models/task_model.dart';
import '../repo/api_task_repository.dart';
import '../repo/mock_task_repository.dart';
import '../repo/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => AppConfig.useApi
      ? ApiTaskRepository(watchApi(ref))
      : MockTaskRepository(),
);

final tasksProvider = AsyncNotifierProvider<TasksController, List<TaskModel>>(
  TasksController.new,
);

class TasksController extends AsyncNotifier<List<TaskModel>> {
  TaskRepository get _repository => ref.read(taskRepositoryProvider);

  @override
  Future<List<TaskModel>> build() {
    ref.watch(authProvider.select((user) => user?.id));
    return ref.watch(taskRepositoryProvider).getAll();
  }

  Future<void> add(TaskModel task) async {
    _show([..._current, task]..sort((a, b) => a.dueAt.compareTo(b.dueAt)));
    await _repository.add(task);
  }

  Future<void> toggle(TaskModel task) async {
    _show([
      for (final t in _current)
        t.id == task.id ? t.copyWith(isDone: !t.isDone) : t,
    ]);
    await _repository.setDone(task.id, !task.isDone);
  }

  Future<void> delete(TaskModel task) async {
    _show(_current.where((t) => t.id != task.id).toList());
    await _repository.delete(task.id);
  }

  List<TaskModel> get _current => state.valueOrNull ?? [];

  void _show(List<TaskModel> tasks) => state = AsyncData(tasks);
}
