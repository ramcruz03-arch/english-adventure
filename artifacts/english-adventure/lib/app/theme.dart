import 'package:flutter/material.dart';

/// Design tokens for English Adventure.
///
/// Direction: a South Indian garden at mid-morning. The guide is Anil, a
/// three-striped palm squirrel. Every colour is drawn from that world.
///
/// The warm-oat background is an accessibility decision, not a style one:
/// pure white on a bright phone screen causes glare and visual crowding for
/// readers with dyslexia-like difficulties. Ink is dark bark brown, not black,
/// for the same reason.
class Tokens {
  // Palette
  static const paper = Color(0xFFF7EFE2);      // warm oat - low-glare reading surface
  static const paperDeep = Color(0xFFEDE0CB);  // card wells, inactive tiles
  static const ink = Color(0xFF33241A);        // bark brown - body text
  static const inkSoft = Color(0xFF6B5847);    // secondary text
  static const leaf = Color(0xFF2F7D4F);       // growth, "you did it"
  static const leafLight = Color(0xFFBFE0CB);
  static const marigold = Color(0xFFF2A63B);   // stars and rewards - the one bright note
  static const hibiscus = Color(0xFFD3455B);   // Anil's scarf ONLY - never an error colour
  static const sky = Color(0xFF7FB6D9);        // audio / listening affordances

  // Type roles
  static const learningFace = 'Andika';        // child-facing letters and words
  static const uiFace = 'Lexend';              // parent-facing UI
  static const displayFace = 'BalooThambi2';   // headings, Latin + Tamil

  // Scale - child-facing minimums are non-negotiable
  static const soundStoneSize = 168.0;
  static const wordSize = 44.0;
  static const sentenceSize = 32.0;
  static const bodySize = 20.0;
  static const minTap = 64.0;

  static const radius = 24.0;
  static const gutter = 16.0;
}

/// Accessibility overrides a parent can set. Applied globally.
class ReadingPrefs {
  const ReadingPrefs({
    this.textScale = 1.0,
    this.letterSpacing = 0.0,
    this.lineHeight = 1.6,
    this.reduceMotion = false,
    this.face = Tokens.learningFace,
    this.language = 'en',
  });

  final double textScale;
  final double letterSpacing;
  final double lineHeight;
  final bool reduceMotion;
  final String face;
  final String language;

  ReadingPrefs copyWith({
    double? textScale,
    double? letterSpacing,
    double? lineHeight,
    bool? reduceMotion,
    String? face,
    String? language,
  }) =>
      ReadingPrefs(
        textScale: textScale ?? this.textScale,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        lineHeight: lineHeight ?? this.lineHeight,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        face: face ?? this.face,
        language: language ?? this.language,
      );
}

ThemeData buildTheme(ReadingPrefs p) {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Tokens.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Tokens.leaf,
      surface: Tokens.paper,
      brightness: Brightness.light,
    ),
  );

  TextStyle t(double size, {FontWeight w = FontWeight.w600, Color c = Tokens.ink}) => TextStyle(
        fontFamily: p.face,
        fontSize: size * p.textScale,
        fontWeight: w,
        color: c,
        letterSpacing: p.letterSpacing * size,
        height: p.lineHeight,
      );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: t(Tokens.soundStoneSize, w: FontWeight.w700),
      headlineLarge: t(Tokens.wordSize, w: FontWeight.w700),
      titleLarge: t(Tokens.sentenceSize),
      bodyLarge: t(Tokens.bodySize, w: FontWeight.w500),
      bodyMedium: t(Tokens.bodySize - 2, w: FontWeight.w400, c: Tokens.inkSoft),
    ),
  );
}
