import '../../assignments/models/attachment_model.dart';

abstract class FileRepository {
  Future<AttachmentModel> upload(String name, List<int> bytes);

  Future<Uri?> linkTo(AttachmentModel file);
}
