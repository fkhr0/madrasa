import '../data/mock_tasks.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

/// Keeps tasks in memory so adding / ticking works during the session.
class MockTaskRepository implements TaskRepository {
  final List<TaskModel> _items = MockTasks.items;

  @override
  Future<List<TaskModel>> getAll() async {
    return [..._items]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  }

  @override
  Future<void> add(TaskModel task) async => _items.add(task);

  @override
  Future<void> setDone(String id, bool isDone) async {
    final index = _items.indexWhere((t) => t.id == id);
    if (index != -1) _items[index] = _items[index].copyWith(isDone: isDone);
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((t) => t.id == id);
}
