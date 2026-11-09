import '../../auth/data/mock_users.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class MockMessages {
  MockMessages._();

  static DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(
        Duration(days: days, hours: hours, minutes: minutes),
      );

  /// Which conversations each demo account takes part in.
  static List<String> conversationIdsOf(String userId) {
    if (userId == MockUsers.teacher.id) return ['t1', 't2', 't3', 't4'];
    if (userId == MockUsers.parent.id) return ['p1', 'p2', 'p3'];
    if (userId == MockUsers.admin.id) return ['a1', 'a2'];

    return ['c1', 'c2', 'c3', 'c4', 'c5'];
  }

  static List<ConversationModel> get teacherConversations => [
    ConversationModel(
      id: 't1',
      title: 'Zainab Haider',
      subtitle: 'Student · 5th Scientific – A',
      lastMessage: 'Yes, question 7 is optional this time.',
      lastMessageAt: _ago(minutes: 12),
    ),
    ConversationModel(
      id: 't2',
      title: 'Mathematics – 5th Scientific – A',
      subtitle: '12 students',
      isGroup: true,
      lastMessage: 'You: Monthly exam on Monday, chapters 2 and 3.',
      lastMessageAt: _ago(hours: 5),
    ),
    ConversationModel(
      id: 't3',
      title: 'Haider Jasim',
      subtitle: 'Parent of Zainab Haider',
      lastMessage: 'Thank you for the update, teacher.',
      lastMessageAt: _ago(days: 1),
      unreadCount: 1,
    ),
    ConversationModel(
      id: 't4',
      title: 'Mathematics department',
      subtitle: '6 teachers',
      isGroup: true,
      lastMessage: 'Ms. Sara: Shared the monthly exam template.',
      lastMessageAt: _ago(days: 2),
    ),
  ];

  static List<ConversationModel> get adminConversations => [
    ConversationModel(
      id: 'a1',
      title: 'All teachers',
      subtitle: '24 members',
      isGroup: true,
      lastMessage: 'You: Monthly exam marks are due by Thursday.',
      lastMessageAt: _ago(hours: 3),
    ),
    ConversationModel(
      id: 'a2',
      title: 'Mr. Ahmed Kareem',
      subtitle: 'Mathematics teacher',
      lastMessage: 'The department meeting room is booked.',
      lastMessageAt: _ago(days: 1),
      unreadCount: 1,
    ),
  ];

  static List<ConversationModel> get parentConversations => [
    ConversationModel(
      id: 'p1',
      title: 'Mr. Ahmed Kareem',
      subtitle: 'Mathematics · Zainab\'s teacher',
      lastMessage: 'Zainab is doing very well this month.',
      lastMessageAt: _ago(days: 1, hours: 1),
    ),
    ConversationModel(
      id: 'p2',
      title: 'Ms. Huda Jaber',
      subtitle: 'Class teacher · 2nd Intermediate – B',
      lastMessage: 'Ali was absent yesterday. Is everything alright?',
      lastMessageAt: _ago(hours: 20),
      unreadCount: 1,
    ),
    ConversationModel(
      id: 'p3',
      title: 'Student Affairs',
      subtitle: 'School office',
      lastMessage: 'The parent–teacher meeting is on Sunday at 2 pm.',
      lastMessageAt: _ago(days: 3),
    ),
  ];

  static List<ConversationModel> get conversations => [
    ConversationModel(
      id: 'c1',
      title: 'Mr. Ahmed Kareem',
      subtitle: 'Mathematics teacher',
      lastMessage: 'Yes, question 7 is optional this time.',
      lastMessageAt: _ago(minutes: 12),
      unreadCount: 1,
    ),
    ConversationModel(
      id: 'c2',
      title: '5th Scientific – A',
      subtitle: '28 members',
      isGroup: true,
      lastMessage: 'Ms. Huda: Don\'t forget your uniform on Tuesday.',
      lastMessageAt: _ago(hours: 2),
      unreadCount: 3,
    ),
    ConversationModel(
      id: 'c3',
      title: 'Chemistry – 5th Scientific',
      subtitle: '30 members',
      isGroup: true,
      lastMessage: 'Mr. Omar: The lab report template is uploaded.',
      lastMessageAt: _ago(days: 1, hours: 1),
    ),
    ConversationModel(
      id: 'c4',
      title: 'Ms. Rana Sami',
      subtitle: 'English teacher',
      lastMessage: 'Thank you, I received your essay.',
      lastMessageAt: _ago(days: 3),
    ),
    ConversationModel(
      id: 'c5',
      title: 'Student Affairs',
      subtitle: 'School office',
      lastMessage: 'Your student card is ready for pick-up.',
      lastMessageAt: _ago(days: 6),
    ),
  ];

  static List<MessageModel> get messages => [
    MessageModel(
      id: 'pm1',
      conversationId: 'p2',
      senderName: 'Ms. Huda Jaber',
      text: 'Ali was absent yesterday. Is everything alright?',
      sentAt: _ago(hours: 20),
      isMine: false,
    ),
    MessageModel(
      id: 'tm1',
      conversationId: 't3',
      senderName: 'Haider Jasim',
      text: 'Thank you for the update, teacher.',
      sentAt: _ago(days: 1),
      isMine: false,
    ),
    MessageModel(
      id: 'm1',
      conversationId: 'c1',
      senderName: 'Zainab Haider',
      text: 'Good morning sir, I have a question about worksheet 4.',
      sentAt: _ago(minutes: 30),
      isMine: true,
    ),
    MessageModel(
      id: 'm2',
      conversationId: 'c1',
      senderName: 'Mr. Ahmed Kareem',
      text: 'Good morning Zainab, go ahead.',
      sentAt: _ago(minutes: 25),
      isMine: false,
    ),
    MessageModel(
      id: 'm3',
      conversationId: 'c1',
      senderName: 'Zainab Haider',
      text:
          'Question 7 uses the formula we haven\'t covered yet. '
          'Do we need to solve it?',
      sentAt: _ago(minutes: 20),
      isMine: true,
    ),
    MessageModel(
      id: 'm4',
      conversationId: 'c1',
      senderName: 'Mr. Ahmed Kareem',
      text: 'Yes, question 7 is optional this time.',
      sentAt: _ago(minutes: 12),
      isMine: false,
    ),
    MessageModel(
      id: 'm5',
      conversationId: 'c2',
      senderName: 'Ms. Huda Jaber',
      text: 'Class photos are on Tuesday morning.',
      sentAt: _ago(hours: 2, minutes: 5),
      isMine: false,
    ),
    MessageModel(
      id: 'm6',
      conversationId: 'c2',
      senderName: 'Ms. Huda Jaber',
      text: 'Don\'t forget your uniform on Tuesday.',
      sentAt: _ago(hours: 2),
      isMine: false,
    ),
  ];
}
