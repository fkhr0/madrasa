import 'package:flutter_test/flutter_test.dart';
import 'package:school/features/resources/models/resource_model.dart';
import 'package:school/features/resources/repo/mock_resource_repository.dart';
import 'package:school/features/tasks/models/task_model.dart';

void main() {
  test('a task goes to the server and comes back the same', () {
    final task = TaskModel(
      id: 'r1',
      title: 'Revise maths',
      note: 'Chapter 3',
      dueAt: DateTime.utc(2026, 11, 9, 16),
      priority: TaskPriority.high,
      repeat: TaskRepeat.weekly,
      isReminder: true,
    );
    final back = TaskModel.fromJson(task.toJson());

    expect(task.toJson()['dueAt'], '2026-11-09T16:00:00.000Z');
    expect(back.title, 'Revise maths');
    expect(back.priority, TaskPriority.high);
    expect(back.repeat, TaskRepeat.weekly);
    expect(back.isReminder, isTrue);
    expect(back.dueAt.isAtSameMomentAs(task.dueAt), isTrue);
  });

  test('material from the server: a file or a link', () {
    final file = ResourceModel.fromJson({
      'id': 'm1',
      'classId': 'cls-5a',
      'title': 'Chapter 3 summary',
      'type': 'pdf',
      'url': null,
      'uploadedAt': '2026-11-05T07:00:00.000Z',
      'subjectId': 'math',
      'subjectName': 'Mathematics',
      'icon': 'math',
      'color': 'purple',
      'fileId': 'f1',
      'fileName': 'Chapter 3.pdf',
      'fileSize': 2516582,
    });
    expect(file.file?.id, 'f1');
    expect(file.detail, '2.4 MB');

    final link = ResourceModel.fromJson({
      'id': 'm2',
      'title': 'Forces simulation',
      'type': 'link',
      'url': 'https://phet.colorado.edu',
      'uploadedAt': '2026-11-05T07:00:00.000Z',
      'subjectId': 'physics',
      'subjectName': 'Physics',
      'fileId': null,
    });
    expect(link.file, isNull);
    expect(link.url, 'https://phet.colorado.edu');
  });

  test('mock: share and remove material for a class', () async {
    final repo = MockResourceRepository();
    await repo.addResource(
      classId: 'cls-5b',
      subjectId: 'math',
      title: 'Khan Academy: functions',
      type: ResourceType.link,
      url: 'https://www.khanacademy.org',
    );
    final shared = (await repo.getClassResources(
      'cls-5b',
    )).firstWhere((r) => r.title == 'Khan Academy: functions');

    await repo.deleteResource(shared.id);
    expect(
      (await repo.getClassResources('cls-5b')).any((r) => r.id == shared.id),
      isFalse,
    );
  });
}
