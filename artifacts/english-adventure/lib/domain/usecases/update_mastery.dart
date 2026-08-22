import '../entities/skill_state.dart';

/// Pure function. No Flutter, no database, no clock injection problems -
/// which is exactly why this is the easiest and most important thing to test.
///
/// outcome: 1.0 correct first try, 0.5 correct after a hint, 0.0 missed.
SkillState applyOutcome(SkillState s, double outcome, {DateTime? now}) {
  final t = now ?? DateTime.now();

  final ema = 0.7 * s.ema + 0.3 * outcome;
  final recent = [...s.recent, outcome].takeLast(3);
  final exposures = s.exposures + 1;
  final correct = s.correctCount + (outcome == 1.0 ? 1 : 0);

  var status = s.status;
  var box = s.leitnerBox;
  DateTime? nextReview = s.nextReviewAt;

  final qualifies = exposures >= 5 && ema >= 0.85 && recent.every((o) => o >= 0.5);

  if (qualifies && status != SkillStatus.mastered) {
    status = SkillStatus.mastered;
    box = 1;
    nextReview = t.add(_boxInterval(1));
  } else if (status == SkillStatus.mastered && ema < 0.6) {
    // Quietly returns to the review queue. The child is never told.
    status = SkillStatus.shaky;
    box = 1;
    nextReview = t;
  } else if (status == SkillStatus.mastered) {
    box = outcome >= 0.5 ? (box + 1).clamp(1, 5) : 1;
    nextReview = t.add(_boxInterval(box));
  } else if (status == SkillStatus.untouched) {
    status = SkillStatus.learning;
  } else if (status == SkillStatus.shaky && ema >= 0.85) {
    status = SkillStatus.mastered;
  }

  // Difficulty follows accuracy only. Response time is recorded for the parent
  // dashboard but never feeds this - slow and correct is fully correct.
  var tier = s.difficultyTier;
  final misses = recent.reversed.takeWhile((o) => o == 0.0).length;
  final wins = recent.reversed.takeWhile((o) => o == 1.0).length;
  if (misses >= 3) tier = (tier - 1).clamp(1, 3);
  if (wins >= 3 && exposures >= 4) tier = (tier + 1).clamp(1, 3);

  return s.copyWith(
    status: status,
    ema: ema,
    exposures: exposures,
    correctCount: correct,
    difficultyTier: tier,
    leitnerBox: box,
    recent: recent,
    nextReviewAt: nextReview,
    lastSeenAt: t,
  );
}

Duration _boxInterval(int box) => switch (box) {
      1 => const Duration(days: 1),
      2 => const Duration(days: 3),
      3 => const Duration(days: 7),
      4 => const Duration(days: 16),
      _ => const Duration(days: 45),
    };

extension _TakeLast<T> on List<T> {
  List<T> takeLast(int n) => length <= n ? this : sublist(length - n);
}
