import '../l10n/language.dart';

/// App-wide texts, in the app's language (see core/l10n).
class AppStrings {
  AppStrings._();

  static String get appName => tr('Madrasa');
  static String get tagline => tr('Your school, in one calm place.');

  static String get genericError =>
      tr('Something went wrong. Please try again.');
  static String get retry => tr('Try again');
  static String get seeAll => tr('See all');
  static String get comingSoon => tr('Coming in a later update');
}
