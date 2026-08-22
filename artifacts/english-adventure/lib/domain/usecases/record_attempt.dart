import '../entities/activity.dart';
import '../entities/skill_state.dart';
import '../repositories/progress_repository.dart';
import 'update_mastery.dart';

class RecordAttempt {
  RecordAttempt(this._progress);
  final ProgressRepository _progress;

  Future<SkillState> call({
    required String childId,
    required String sessionId,
    required String skillId,
    required String skillType,
    required GameMode mode,
    required double outcome,
    int hintsUsed = 0,
    required String attemptKey,
    String? chosenValue,
    int? responseMs,
  }) async {
    final current = await _progress.skill(childId, skillId, skillType);
    final updated = applyOutcome(current, outcome);
    final recorded = await _progress.recordSkillAttempt(
      updatedState: updated,
      sessionId: sessionId,
      childId: childId,
      mode: mode.name,
      skillId: skillId,
      outcome: outcome,
      hintsUsed: hintsUsed,
      attemptKey: attemptKey,
      chosenValue: chosenValue,
      responseMs: responseMs,
    );
    return recorded ? updated : current;
  }
}
