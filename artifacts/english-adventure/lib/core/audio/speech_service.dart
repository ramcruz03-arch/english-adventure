import 'package:flutter_tts/flutter_tts.dart';

/// All child-facing audio goes through this one seam.
///
/// MVP uses device TTS. When recorded human audio arrives, implement
/// [SpeechService] with a file-playing version and change nothing else -
/// no game screen knows how sound is produced.
abstract class SpeechService {
  Future<void> speak(String text, {double rate});

  /// Says the SOUND, not the letter name. This distinction is the single most
  /// common defect in phonics apps: TTS given "b" says "bee", which actively
  /// teaches the child the wrong thing. Content therefore ships an explicit
  /// [ttsFallback] spelling per grapheme ("sss", "mmm", "t").
  Future<void> speakPhoneme(String ttsFallback, {double rate = 0.35});

  Future<void> stop();
  Future<void> setMuted(bool muted);
  bool get isMuted;
}

class TtsSpeechService implements SpeechService {
  TtsSpeechService({this.locale = 'en-GB'});

  final String locale;
  final FlutterTts _tts = FlutterTts();
  bool _muted = false;
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    await _tts.setLanguage(locale);     // en-GB default; en-IN offered in settings
    await _tts.setSpeechRate(0.42);     // child pacing, not adult pacing
    await _tts.setPitch(1.05);
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }

  @override
  bool get isMuted => _muted;

  @override
  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (muted) await _tts.stop();
  }

  @override
  Future<void> speak(String text, {double rate = 0.42}) async {
    if (_muted) return;
    await _ensure();
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  @override
  Future<void> speakPhoneme(String ttsFallback, {double rate = 0.35}) =>
      speak(ttsFallback, rate: rate);

  @override
  Future<void> stop() => _tts.stop();
}
