import '../../../core/network/api_client.dart';
import '../../assignments/models/attachment_model.dart';
import 'file_repository.dart';

/// Files on the school API (server/src/features/files).
class ApiFileRepository implements FileRepository {
  final ApiClient _api;

  const ApiFileRepository(this._api);

  @override
  Future<AttachmentModel> upload(String name, List<int> bytes) async =>
      AttachmentModel.fromJson(
        await _api.upload(
              '/files',
              bytes,
              fileName: name,
              contentType: _contentType(name),
            )
            as Map<String, dynamic>,
      );

  @override
  Future<Uri?> linkTo(AttachmentModel file) async {
    final json = await _api.get('/files/${file.id}/link') as Map;
    return _api.resolve(json['url'] as String);
  }

  /// So the phone opens the file with the right app.
  static String _contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'txt' => 'text/plain; charset=utf-8',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'pptx' =>
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      _ => 'application/octet-stream',
    };
  }
}
