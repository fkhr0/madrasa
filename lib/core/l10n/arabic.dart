import 'arabic_1.dart';
import 'arabic_2.dart';
import 'arabic_3.dart';
import 'arabic_4.dart';

/// Arabic for every English text in the app (the English is the key; see
/// language.dart). Split in four files only to keep each one readable.
/// Placeholders {0}, {1}… stay as they are; their order may change.
const Map<String, String> arabic = {
  ...arabic1,
  ...arabic2,
  ...arabic3,
  ...arabic4,
};
