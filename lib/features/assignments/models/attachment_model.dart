import 'package:flutter/material.dart';
import '../../../core/l10n/language.dart';

enum AttachmentType {
  pdf,
  image,
  document,
  other;

  IconData get icon {
    switch (this) {
      case AttachmentType.pdf:
        return Icons.picture_as_pdf_outlined;
      case AttachmentType.image:
        return Icons.image_outlined;
      case AttachmentType.document:
        return Icons.description_outlined;
      case AttachmentType.other:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class AttachmentModel {
  final String id;
  final String name;
  final AttachmentType type;

  final String size;

  const AttachmentModel({
    this.id = '',
    required this.name,
    required this.type,
    required this.size,
  });

  static AttachmentType typeOf(String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    return switch (ext) {
      'pdf' => AttachmentType.pdf,
      'png' ||
      'jpg' ||
      'jpeg' ||
      'gif' ||
      'webp' ||
      'heic' => AttachmentType.image,
      'doc' ||
      'docx' ||
      'txt' ||
      'odt' ||
      'rtf' ||
      'ppt' ||
      'pptx' => AttachmentType.document,
      _ => AttachmentType.other,
    };
  }

  static String sizeText(int bytes) {
    if (bytes >= 1024 * 1024) {
      return tr('{0} MB', [(bytes / 1024 / 1024).toStringAsFixed(1)]);
    }
    if (bytes >= 1024) return tr('{0} KB', [(bytes / 1024).round()]);
    return '$bytes B';
  }

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return AttachmentModel(
      id: json['id'] as String,
      name: name,
      type: typeOf(name),
      size: sizeText(json['size'] as int? ?? 0),
    );
  }
}
