import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme.dart';

class ReadingPrefsController extends StateNotifier<ReadingPrefs> {
  ReadingPrefsController(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static ReadingPrefs _read(SharedPreferences p) => ReadingPrefs(
        textScale: p.getDouble('a11y.textScale') ?? 1.0,
        letterSpacing: p.getDouble('a11y.letterSpacing') ?? 0.0,
        lineHeight: p.getDouble('a11y.lineHeight') ?? 1.6,
        reduceMotion: p.getBool('a11y.reduceMotion') ?? false,
        face: p.getString('a11y.face') ?? Tokens.learningFace,
        language: p.getString('ui.language') ?? 'en',
      );

  Future<void> setTextScale(double v) async {
    state = state.copyWith(textScale: v);
    await _prefs.setDouble('a11y.textScale', v);
  }

  /// 0.0 / 0.05 / 0.12 em - wider tracking measurably helps many struggling readers.
  Future<void> setLetterSpacing(double v) async {
    state = state.copyWith(letterSpacing: v);
    await _prefs.setDouble('a11y.letterSpacing', v);
  }

  Future<void> setLineHeight(double v) async {
    state = state.copyWith(lineHeight: v);
    await _prefs.setDouble('a11y.lineHeight', v);
  }

  Future<void> setReduceMotion(bool v) async {
    state = state.copyWith(reduceMotion: v);
    await _prefs.setBool('a11y.reduceMotion', v);
  }

  Future<void> setFace(String v) async {
    state = state.copyWith(face: v);
    await _prefs.setString('a11y.face', v);
  }

  Future<void> setLanguage(String v) async {
    state = state.copyWith(language: v);
    await _prefs.setString('ui.language', v);
  }
}
