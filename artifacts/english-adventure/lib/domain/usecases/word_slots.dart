/// The rules of Word Builder, with no Flutter in sight so they can be tested
/// exhaustively.
///
/// A CVC word is a left-to-right sequence of sounds, and blending only works
/// if the child builds it in that order. So slots fill left to right and a
/// letter is only accepted into the slot it belongs in — but a wrong letter is
/// never destroyed or taken away, it simply goes back to the tray.
class SlotBoard {
  SlotBoard(this.targetLetters)
      : placed = List<String?>.filled(targetLetters.length, null);

  final List<String> targetLetters;
  final List<String?> placed;

  int? get activeSlot {
    final i = placed.indexWhere((s) => s == null);
    return i == -1 ? null : i;
  }

  bool get isComplete => placed.every((s) => s != null);

  /// Which letters are still in the tray. Duplicates matter: "dad" has two d's
  /// and placing one must not empty the tray of both.
  List<String> remaining() {
    final left = [...targetLetters];
    for (final p in placed) {
      if (p != null) left.remove(p);
    }
    return left;
  }

  bool accepts(String letter) {
    final slot = activeSlot;
    return slot != null && targetLetters[slot] == letter;
  }

  /// Returns the slot the letter landed in, or null if it belongs elsewhere.
  int? place(String letter) {
    final slot = activeSlot;
    if (slot == null || targetLetters[slot] != letter) return null;
    placed[slot] = letter;
    return slot;
  }

  /// Used after two misses: the app finishes the step for the child rather
  /// than letting her grind on it.
  int? placeCorrectOne() {
    final slot = activeSlot;
    if (slot == null) return null;
    placed[slot] = targetLetters[slot];
    return slot;
  }

  void reset() {
    for (var i = 0; i < placed.length; i++) {
      placed[i] = null;
    }
  }
}
