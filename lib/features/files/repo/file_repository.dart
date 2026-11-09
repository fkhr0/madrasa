import '../../assignments/models/attachment_model.dart';

/// Uploading and opening files. MockFileRepository or ApiFileRepository.
abstract class FileRepository {
  /// Uploads the bytes; the returned attachment's ID is then handed in or
  /// attached.
  Future<AttachmentModel> upload(String name, List<int> bytes);

  /// A link that opens the file (valid for a few minutes), or null when
  /// files can't be opened (mock mode).
  Future<Uri?> linkTo(AttachmentModel file);
}
