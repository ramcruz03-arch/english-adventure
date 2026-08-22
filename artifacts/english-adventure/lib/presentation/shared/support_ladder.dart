import 'package:flutter/foundation.dart';

import '../../core/audio/praise.dart';

enum SupportLevel { none, hint, demonstrate }

/// Per-item state machine for the support ladder:
///   miss 1 -> hint (dim distractors, slow the sound)
///   miss 2 -> demonstrate (glow the answer, say it, child taps along)
///   miss 3 -> end the activity warmly and lower difficulty
///
/// There is no fourth branch. There is no failure state anywhere in this file.
class ItemProgress {
  ItemProgress();

  int misses = 0;
  bool solved = false;

  SupportLevel get support => switch (misses) {
        0 => SupportLevel.none,
        1 => SupportLevel.hint,
        _ => SupportLevel.demonstrate,
      };

  /// 1.0 first try, 0.5 after support, 0.0 never got there unaided.
  double get outcome => solved ? (misses == 0 ? 1.0 : 0.5) : 0.0;

  String get guideLine => switch (support) {
        SupportLevel.none => Praise.pick(Praise.success),
        SupportLevel.hint => Praise.pick(Praise.firstHint),
        SupportLevel.demonstrate => Praise.pick(Praise.demonstrate),
      };
}

class FrustrationWatcher extends ChangeNotifier {
  final _taps = <DateTime>[];
  int _consecutiveMisses = 0;

  void recordTap() {
    _taps.add(DateTime.now());
    if (_taps.length > 8) _taps.removeAt(0);
  }

  void recordOutcome(bool correct) {
    _consecutiveMisses = correct ? 0 : _consecutiveMisses + 1;
    notifyListeners();
  }

  bool get shouldOfferBreak {
    if (_consecutiveMisses >= 3) return true;
    if (_taps.length >= 6) {
      final gaps = <int>[];
      for (var i = 1; i < _taps.length; i++) {
        gaps.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
      }
      gaps.sort();
      // Random mashing: fast, undirected taps.
      if (gaps[gaps.length ~/ 2] < 400) return true;
    }
    return false;
  }

  void reset() {
    _taps.clear();
    _consecutiveMisses = 0;
  }
}
