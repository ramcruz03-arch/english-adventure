import 'package:english_adventure/domain/entities/skill_state.dart';
import 'package:english_adventure/domain/usecases/update_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

SkillState _fresh() =>
    const SkillState(childId: 'c1', skillId: 'g:s', skillType: 'grapheme');

void main() {
  test('a skill is never mastered on a lucky streak alone', () {
    var s = _fresh();
    for (var i = 0; i < 4; i++) {
      s = applyOutcome(s, 1.0);
    }
    expect(s.status, SkillStatus.learning, reason: 'needs at least 5 exposures');
  });

  test('five confident successes reach mastery and schedule a review', () {
    var s = _fresh();
    for (var i = 0; i < 6; i++) {
      s = applyOutcome(s, 1.0);
    }
    expect(s.status, SkillStatus.mastered);
    expect(s.leitnerBox, greaterThanOrEqualTo(1));
    expect(s.nextReviewAt, isNotNull);
  });

  test('a mastered skill that decays returns to review, quietly', () {
    var s = _fresh();
    for (var i = 0; i < 6; i++) {
      s = applyOutcome(s, 1.0);
    }
    for (var i = 0; i < 5; i++) {
      s = applyOutcome(s, 0.0);
    }
    expect(s.status, SkillStatus.shaky);
    expect(s.leitnerBox, 1);
  });

  test('three misses lower the difficulty tier rather than the child', () {
    var s = _fresh().copyWith(difficultyTier: 3);
    for (var i = 0; i < 3; i++) {
      s = applyOutcome(s, 0.0);
    }
    expect(s.difficultyTier, 2);
  });

  test('help still counts as success, worth half', () {
    var s = _fresh();
    s = applyOutcome(s, 0.5);
    expect(s.ema, closeTo(0.15, 0.001));
    expect(s.status, SkillStatus.learning);
  });
}
