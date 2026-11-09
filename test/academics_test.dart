import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school/core/network/api_exception.dart';
import 'package:school/core/theme/app_palette.dart';
import 'package:school/features/academics/models/school_class_model.dart';
import 'package:school/features/academics/models/school_subject_model.dart';
import 'package:school/features/academics/repo/mock_academics_repository.dart';
import 'package:school/features/tasks/models/task_model.dart';
import 'package:school/features/tasks/widgets/task_tile.dart';

void main() {
  group('Academics (admin full control)', () {
    test('subjects: add, rename everywhere, delete from classes', () async {
      final repo = MockAcademicsRepository();
      await repo.saveSubject(
        const SchoolSubjectModel(
          id: '',
          name: 'Geography',
          iconKey: 'geography',
        ),
      );
      final geo = (await repo.getSubjects()).firstWhere(
        (s) => s.name == 'Geography',
      );

      // Same name twice is refused.
      expect(
        () => repo.saveSubject(
          const SchoolSubjectModel(id: '', name: 'geography'),
        ),
        throwsA(isA<ApiException>()),
      );

      await repo.setSubjectTeacher(
        classId: 'cls-4a',
        subjectId: geo.id,
        teacherId: 'TCH-2019-0040',
      );
      await repo.saveSubject(geo.copyWith(name: 'Iraqi Geography'));
      expect(
        (await _byId(
          repo,
          'cls-4a',
        )).subjects.any((s) => s.subjectName == 'Iraqi Geography'),
        isTrue,
      );

      await repo.deleteSubject(geo.id);
      expect(
        (await _byId(
          repo,
          'cls-4a',
        )).subjects.any((s) => s.subjectId == geo.id),
        isFalse,
      );
    });

    test('classes: head teacher, subject teachers, delete rules', () async {
      final repo = MockAcademicsRepository();
      await repo.saveClass(
        name: '4th Scientific – B',
        homeroomTeacherId: 'TCH-2019-0045',
        subjectIds: ['math', 'physics'],
      );
      final added = (await repo.getClasses()).firstWhere(
        (c) => c.name == '4th Scientific – B',
      );
      expect(added.homeroomTeacherName, 'Noor Abbas');
      expect(added.unassignedCount, 2);

      await repo.setSubjectTeacher(
        classId: added.id,
        subjectId: 'math',
        teacherId: 'TCH-2019-0031',
      );
      await repo.removeSubjectFromClass(
        classId: added.id,
        subjectId: 'physics',
      );
      final updated = await _byId(repo, added.id);
      expect(updated.subjects.single.teacherName, 'Ahmed Kareem');

      await repo.deleteClass(added.id);
      expect(
        () => repo.deleteClass('cls-5a'), // has students
        throwsA(isA<ApiException>()),
      );
    });
  });

  testWidgets('swiping a task away asks first', (tester) async {
    final task = TaskModel(
      id: 't1',
      title: 'Revise chapter 3',
      dueAt: DateTime.now().add(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(extensions: const [AppPalette.light]),
          home: Scaffold(body: TaskTile(task: task)),
        ),
      ),
    );

    await tester.drag(find.text('Revise chapter 3'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // Still there.
    expect(find.text('Revise chapter 3'), findsOneWidget);
  });
}

Future<SchoolClassModel> _byId(MockAcademicsRepository repo, String id) async =>
    (await repo.getClasses()).firstWhere((c) => c.id == id);
