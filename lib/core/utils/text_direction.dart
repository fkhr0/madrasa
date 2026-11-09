import 'package:flutter/widgets.dart';

/// The direction a piece of text reads in, from its first letter: a message
/// starting in Arabic reads right to left even when the app is in English, and
/// an English one left to right in the Arabic app (like WhatsApp).
TextDirection? directionOf(String text) {
  for (final rune in text.runes) {
    // Arabic letters (and Persian/Urdu ones) and Hebrew.
    if ((rune >= 0x0590 && rune <= 0x08FF) ||
        (rune >= 0xFB1D && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      return TextDirection.rtl;
    }
    if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0xC0 && rune <= 0x24F)) {
      return TextDirection.ltr;
    }
  }
  return null;
}
