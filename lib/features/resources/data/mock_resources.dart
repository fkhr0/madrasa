import '../../subjects/data/mock_subjects.dart';
import '../models/resource_model.dart';

class MockResources {
  MockResources._();

  static DateTime _ago(int days) =>
      DateTime.now().subtract(Duration(days: days));

  static List<ResourceModel> get items => [
    ResourceModel(
      id: 'r1',
      title: 'Chapter 3 – Functions (summary)',
      subject: MockSubjects.math,
      type: ResourceType.pdf,
      uploadedAt: _ago(1),
      detail: '1.8 MB',
    ),
    ResourceModel(
      id: 'r2',
      title: 'Solving quadratic equations',
      subject: MockSubjects.math,
      type: ResourceType.video,
      uploadedAt: _ago(4),
      detail: '14 min',
    ),
    ResourceModel(
      id: 'r3',
      title: 'Newton\'s laws – lesson slides',
      subject: MockSubjects.physics,
      type: ResourceType.slides,
      uploadedAt: _ago(2),
      detail: '5.2 MB',
    ),
    ResourceModel(
      id: 'r4',
      title: 'Forces simulation (PhET)',
      subject: MockSubjects.physics,
      type: ResourceType.link,
      uploadedAt: _ago(6),
    ),
    ResourceModel(
      id: 'r5',
      title: 'Lab safety rules',
      subject: MockSubjects.chemistry,
      type: ResourceType.pdf,
      uploadedAt: _ago(12),
      detail: '420 KB',
    ),
    ResourceModel(
      id: 'r6',
      title: 'Chemical bonding explained',
      subject: MockSubjects.chemistry,
      type: ResourceType.video,
      uploadedAt: _ago(3),
      detail: '9 min',
    ),
    ResourceModel(
      id: 'r7',
      title: 'Poetry analysis guide',
      subject: MockSubjects.arabic,
      type: ResourceType.pdf,
      uploadedAt: _ago(8),
      detail: '980 KB',
    ),
    ResourceModel(
      id: 'r8',
      title: 'Descriptive writing tips',
      subject: MockSubjects.english,
      type: ResourceType.slides,
      uploadedAt: _ago(5),
      detail: '3.1 MB',
    ),
    ResourceModel(
      id: 'r9',
      title: 'Python basics – practice sheet',
      subject: MockSubjects.computer,
      type: ResourceType.pdf,
      uploadedAt: _ago(7),
      detail: '600 KB',
    ),
  ];
}
