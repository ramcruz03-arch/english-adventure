enum SkillStatus { untouched, learning, mastered, shaky }

/// What the app knows about one child and one skill.
/// A skill is a grapheme ('g:s'), a word ('w:cat'), a sight word ('sw:the'),
/// or a tracing glyph ('tr:a').
class SkillState {
  const SkillState({
    required this.childId,
    required this.skillId,
    required this.skillType,
    this.status = SkillStatus.untouched,
    this.ema = 0.0,
    this.exposures = 0,
    this.correctCount = 0,
    this.difficultyTier = 1,
    this.leitnerBox = 0,
    this.recent = const [],
    this.nextReviewAt,
    this.lastSeenAt,
  });

  final String childId;
  final String skillId;
  final String skillType;
  final SkillStatus status;
  final double ema;
  final int exposures;
  final int correctCount;
  final int difficultyTier; // 1..3 -> 2, 3, 4 choices
  final int leitnerBox;     // 0 = not scheduled, 1..5
  final List<double> recent; // last 3 outcomes
  final DateTime? nextReviewAt;
  final DateTime? lastSeenAt;

  bool get isDue =>
      nextReviewAt != null && !nextReviewAt!.isAfter(DateTime.now());

  SkillState copyWith({
    SkillStatus? status,
    double? ema,
    int? exposures,
    int? correctCount,
    int? difficultyTier,
    int? leitnerBox,
    List<double>? recent,
    DateTime? nextReviewAt,
    DateTime? lastSeenAt,
  }) =>
      SkillState(
        childId: childId,
        skillId: skillId,
        skillType: skillType,
        status: status ?? this.status,
        ema: ema ?? this.ema,
        exposures: exposures ?? this.exposures,
        correctCount: correctCount ?? this.correctCount,
        difficultyTier: difficultyTier ?? this.difficultyTier,
        leitnerBox: leitnerBox ?? this.leitnerBox,
        recent: recent ?? this.recent,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      );
}
