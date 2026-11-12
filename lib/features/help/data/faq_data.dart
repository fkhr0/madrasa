import '../models/faq_model.dart';

/// App help content. Stays in the app (not from the server).
class FaqData {
  FaqData._();

  static const items = [
    FaqModel(
      question: 'I forgot my password. What do I do?',
      answer:
          'On the sign-in page tap "Forgot password?" and enter the email or '
          'phone linked to your account. If that doesn\'t work, ask the school '
          'office to reset it for you.',
    ),
    FaqModel(
      question: 'Where do I find my school ID?',
      answer:
          'Your school gives every student, teacher and parent an ID. It is '
          'printed on your student card and shown on your Profile page.',
    ),
    FaqModel(
      question: 'How do I hand in an assignment?',
      answer:
          'Open the assignment, add your files under "Your work", then tap '
          '"Hand in". If the due date has passed, you can still hand in when '
          'your teacher allows late work.',
    ),
    FaqModel(
      question: 'My grade or attendance looks wrong.',
      answer:
          'Send a message to your teacher from the Messages tab, or contact '
          'the school from this page. Only the school can correct records.',
    ),
    FaqModel(
      question: 'How do I stop some notifications?',
      answer:
          'Go to More → Settings → Notifications and turn off the kinds you '
          'don\'t need.',
    ),
  ];
}
