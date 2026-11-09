import '../../../core/network/api_client.dart';
import '../models/task_model.dart';
import 'task_repository.dart';

/// The signed-in person's own tasks on the school API
/// (server/src/features/tasks).
class ApiTaskRepository implements TaskRepository {
  final ApiClient _api;

  const ApiTaskRepository(this._api);

  @override
  Future<List<TaskModel>> getAll() async => [
    for (final json in await _api.get('/tasks') as List)
      TaskModel.fromJson(json as Map<String, dynamic>),
  ];

  @override
  Future<void> add(TaskModel task) => _api.post('/tasks', task.toJson());

  @override
  Future<void> setDone(String id, bool isDone) =>
      _api.patch('/tasks/$id', {'isDone': isDone});

  @override
  Future<void> delete(String id) => _api.delete('/tasks/$id');
}
