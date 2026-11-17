import '../../assignments/models/attachment_model.dart';
import 'file_repository.dart';

class MockFileRepository implements FileRepository {
  int _nextId = 1;

  @override
  Future<AttachmentModel> upload(String name, List<int> bytes) async =>
      AttachmentModel(
        id: 'mock-file-${_nextId++}',
        name: name,
        type: AttachmentModel.typeOf(name),
        size: AttachmentModel.sizeText(bytes.length),
      );

  @override
  Future<Uri?> linkTo(AttachmentModel file) async => null;
}
