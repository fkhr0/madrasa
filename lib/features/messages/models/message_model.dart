import 'package:flutter/material.dart';

enum MessageStatus {
  sending,
  sent,
  read,

  failed;

  IconData get icon {
    switch (this) {
      case MessageStatus.sending:
        return Icons.schedule;
      case MessageStatus.sent:
        return Icons.done;
      case MessageStatus.read:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error_outline;
    }
  }
}

class MessageModel {
  final String id;
  final String conversationId;
  final String senderName;
  final String text;
  final DateTime sentAt;

  final bool isMine;
  final MessageStatus status;

  final bool edited;

  final bool deleted;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderName,
    required this.text,
    required this.sentAt,
    required this.isMine,
    this.status = MessageStatus.read,
    this.edited = false,
    this.deleted = false,
  });

  static const editableFor = Duration(minutes: 15);

  bool get canEdit =>
      isMine &&
      !deleted &&
      !isLocal &&
      DateTime.now().difference(sentAt) < editableFor;

  bool get isLocal => id.startsWith(localIdPrefix);

  static const localIdPrefix = 'local-';

  MessageModel copyWith({
    MessageStatus? status,
    String? text,
    bool? edited,
    bool? deleted,
  }) => MessageModel(
    id: id,
    conversationId: conversationId,
    senderName: senderName,
    text: text ?? this.text,
    sentAt: sentAt,
    isMine: isMine,
    status: status ?? this.status,
    edited: edited ?? this.edited,
    deleted: deleted ?? this.deleted,
  );

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    required String conversationId,
  }) => MessageModel(
    id: json['id'] as String,
    conversationId: conversationId,
    senderName: json['senderName'] as String? ?? '',
    text: json['text'] as String,
    sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
    isMine: json['isMine'] as bool? ?? false,
    status: json['seen'] == true ? MessageStatus.read : MessageStatus.sent,
    edited: json['edited'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
  );
}
