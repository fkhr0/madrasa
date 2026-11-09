import '../models/task_model.dart';

class MockTasks {
  MockTasks._();

  static DateTime _day(int offset, int hour, [int minute = 0]) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + offset, hour, minute);
  }

  static List<TaskModel> get items => [
    TaskModel(
      id: 't1',
      title: 'Review chapter 3 for the math mid-term',
      note: 'Focus on functions and inequalities.',
      dueAt: _day(0, 19),
      priority: TaskPriority.high,
    ),
    TaskModel(
      id: 't2',
      title: 'Read 20 pages of the English novel',
      dueAt: _day(0, 21),
      isReminder: true,
      priority: TaskPriority.low,
      repeat: TaskRepeat.daily,
    ),
    TaskModel(id: 't3', title: 'Bring lab coat', dueAt: _day(1, 7, 30)),
    TaskModel(
      id: 't4',
      title: 'Make flashcards for chemistry',
      dueAt: _day(3, 18),
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: 't5',
      title: 'Return library book',
      dueAt: _day(-1, 14),
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: 't6',
      title: 'Print Islamic Education summary',
      dueAt: _day(-2, 20),
      isDone: true,
    ),
  ];
}
