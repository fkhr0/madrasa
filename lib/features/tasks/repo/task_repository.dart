import '../models/task_model.dart';

abstract class TaskRepository {
  Future<List<TaskModel>> getAll();

  Future<void> add(TaskModel task);

  Future<void> setDone(String id, bool isDone);

  Future<void> delete(String id);
}
