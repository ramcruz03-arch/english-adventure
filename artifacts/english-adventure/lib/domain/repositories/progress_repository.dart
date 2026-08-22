import '../entities/skill_state.dart';
import '../entities/activity.dart';
import '../entities/resumable_session.dart';

abstract class ProgressRepository {
  Future<SkillState> skill(String childId, String skillId, String skillType);
  Future<List<SkillState>> allSkills(String childId);
  Future<void> saveSkill(SkillState state);
  Future<bool> recordSkillAttempt({
    required SkillState updatedState,
    required String sessionId,
    required String childId,
    required String mode,
    required String skillId,
    required double outcome,
    required int hintsUsed,
    required String attemptKey,
    String? chosenValue,
    int? responseMs,
  });

  Future<String> startSession(String childId, {List<Activity> path = const []});
  Future<ResumableSession?> unfinishedSession(String childId) async => null;
  Future<void> saveSessionPlan(String sessionId, List<Activity> path) async {}
  Future<void> saveSessionProgress(String sessionId,
      {required int currentActivity, required int stars}) async {}
  Future<bool> advanceSession(String sessionId,
          {required int expectedActivity,
          required int nextActivity,
          required int stars}) async =>
      false;
  Future<void> endSession(String sessionId,
      {required int seconds,
      required int activities,
      required int stars,
      required String reason});

  Future<bool> logAttempt({
    required String sessionId,
    required String childId,
    required String mode,
    required String skillId,
    required double outcome,
    required int hintsUsed,
    String? attemptKey,
    String? chosenValue,
    int? responseMs,
  });

  /// Accuracy of the child's previous session, used to decide whether it is
  /// fair to introduce new material today.
  Future<double> lastSessionAccuracy(String childId);

  Future<void> saveTracingSample({
    required String childId,
    required String glyphId,
    required double coverage,
    required double meanDeviation,
    required bool strokeOrderOk,
    String? sampleKey,
  });

  /// Permanently removes every child and progress record stored locally.
  ///
  /// This is intentionally an all-or-nothing operation for the parent area:
  /// callers must not need to know which local tables hold child data.
  Future<void> deleteAllData();
}
