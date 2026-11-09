import '../models/task_model.dart';

/// The signed-in person's own tasks and reminders.
/// MockTaskRepository or ApiTaskRepository.
abstract class TaskRepository {
  /// Earliest due first.
  Future<List<TaskModel>> getAll();

  Future<void> add(TaskModel task);

  Future<void> setDone(String id, bool isDone);

  Future<void> delete(String id);
}
