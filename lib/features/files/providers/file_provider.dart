import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_provider.dart';
import '../../../core/utils/context_extensions.dart';
import '../../assignments/models/attachment_model.dart';
import '../repo/api_file_repository.dart';
import '../repo/file_repository.dart';
import '../repo/mock_file_repository.dart';

final fileRepositoryProvider = Provider<FileRepository>(
  (ref) => AppConfig.useApi
      ? ApiFileRepository(watchApi(ref))
      : MockFileRepository(),
);

const maxVideoMb = 50;
const maxFileMb = 10;

const videoExtensions = ['mp4'];

int maxMbFor(String name) =>
    videoExtensions.contains(name.split('.').last.toLowerCase())
    ? maxVideoMb
    : maxFileMb;

const allowedExtensions = [
  'pdf',
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'heic',
  'mp4',
  'm4a',
  'mp3',
  'docx',
  'xlsx',
  'pptx',
  'doc',
  'xls',
  'ppt',
  'txt',
  'csv',
];

Future<List<AttachmentModel>> pickAndUpload(
  BuildContext context,
  WidgetRef ref, {
  List<String> extensions = allowedExtensions,
}) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
  );

  final uploaded = <AttachmentModel>[];
  for (final file in picked) {
    final size = file.lengthSync() ?? await file.length() ?? 0;
    final mostMb = maxMbFor(file.name);
    if (size > mostMb * 1024 * 1024) {
      if (context.mounted) {
        context.showMessage(
          tr('{0} is too big. The most for this kind of file is {1} MB.', [
            file.name,
            mostMb,
          ]),
        );
      }
      continue;
    }
    final bytes = await file.readAsBytes();
    try {
      uploaded.add(
        await ref.read(fileRepositoryProvider).upload(file.name, bytes),
      );
    } on ApiException catch (e) {
      if (context.mounted) context.showMessage(e.message);
    }
  }
  return uploaded;
}

Future<void> openFile(
  BuildContext context,
  WidgetRef ref,
  AttachmentModel file,
) async {
  try {
    final link = await ref.read(fileRepositoryProvider).linkTo(file);
    if (link == null) {
      if (context.mounted) {
        context.showMessage(tr('Files open in the server version of the app'));
      }
      return;
    }
    await launchUrl(link, mode: LaunchMode.externalApplication);
  } on ApiException catch (e) {
    if (context.mounted) context.showMessage(e.message);
  }
}
