/// A private chat or a class / subject group.
class ConversationModel {
  final String id;
  final String title;

  /// e.g. "Mathematics teacher" or "24 members".
  final String subtitle;
  final bool isGroup;

  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  const ConversationModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.lastMessage,
    required this.lastMessageAt,
    this.isGroup = false,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final isGroup = json['isGroup'] as bool? ?? false;
    final lastSender = json['lastSender'] as String?;
    final last = json['lastMessage'] as String? ?? '';

    return ConversationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      isGroup: isGroup,
      // In a group, say who wrote the last message.
      lastMessage: isGroup && lastSender != null && last.isNotEmpty
          ? '${lastSender.split(' ').first}: $last'
          : last,
      lastMessageAt: DateTime.parse(json['lastMessageAt'] as String).toLocal(),
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }

  ConversationModel copyWith({
    String? lastMessage,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return ConversationModel(
      id: id,
      title: title,
      subtitle: subtitle,
      isGroup: isGroup,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Someone the user may start a private chat with.
class ContactModel {
  final String id;
  final String name;

  /// e.g. "Mathematics teacher", "Parent", "School office".
  final String detail;

  const ContactModel({
    required this.id,
    required this.name,
    required this.detail,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) => ContactModel(
    id: json['id'] as String,
    name: json['name'] as String,
    detail: json['detail'] as String? ?? '',
  );
}
