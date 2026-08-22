import 'dart:math';

import '../entities/activity.dart';
import '../entities/skill_state.dart';
import '../entities/word.dart';
import '../content/mini_story.dart';
import '../repositories/content_repository.dart';
import '../repositories/progress_repository.dart';

/// Assembles today's 3-5 activity session (10-15 minutes).
///
/// Three rules are enforced here and nowhere else:
///   1. At most ONE new grapheme per session.
///   2. No new material at all after a session below 60% accuracy.
///   3. The session always ends on something the child can already do.
class BuildDailyPath {
  BuildDailyPath(
    this._content,
    this._progress, {
    Random? rng,
    DateTime Function()? clock,
  })  : _rng = rng ?? Random(),
        _clock = clock ?? DateTime.now;

  final ContentRepository _content;
  final ProgressRepository _progress;
  final Random _rng;
  final DateTime Function() _clock;

  Future<List<Activity>> call(
      {required String childId, int targetMinutes = 12}) async {
    final states = await _progress.allSkills(childId);
    final byId = {for (final s in states) s.skillId: s};

    final taught = states
        .where((s) =>
            s.skillType == 'grapheme' && s.status != SkillStatus.untouched)
        .map((s) => s.skillId)
        .toSet();

    final nextNew = _content.curriculumOrder.firstWhere(
      (id) => !taught.contains(id),
      orElse: () => '',
    );

    final learningCount = states
        .where((s) =>
            s.skillType == 'grapheme' && s.status == SkillStatus.learning)
        .length;
    final accuracy = await _progress.lastSessionAccuracy(childId);
    final mayIntroduce =
        nextNew.isNotEmpty && accuracy >= 0.6 && learningCount < 3;

    final path = <Activity>[];

    if (mayIntroduce) {
      final initialWords = _content.words
          .where((w) =>
              w.graphemeIds.isNotEmpty && w.graphemeIds.first == nextNew)
          .length;
      if (initialWords >= 3) {
        path.add(Activity(
          mode: GameMode.letterGarden,
          targetSkillId: nextNew,
          tier: 1,
        ));
      }
      path.add(Activity(
        mode: GameMode.soundDetective,
        targetSkillId: nextNew,
        tier: byId[nextNew]?.difficultyTier ?? 1,
      ));
    }

    // Shaky skills first, then anything the Leitner scheduler says is due.
    final review = [
      ...states.where((s) => s.status == SkillStatus.shaky),
      ...states.where((s) => s.status == SkillStatus.mastered && s.isDue),
    ].where((s) => s.skillType == 'grapheme').take(2);

    for (final s in review) {
      path.add(Activity(
        mode: GameMode.soundDetective,
        targetSkillId: s.skillId,
        tier: s.difficultyTier,
      ));
    }

    final taughtNow = {...taught, if (mayIntroduce) nextNew};
    final decodable = _content.words
        .where((w) => w.type == WordType.cvc && w.isDecodableWith(taughtNow))
        .toList()
      ..shuffle(_rng);
    final safeDecodable = _content.words
        .where((w) => w.type == WordType.cvc && w.isDecodableWith(taught))
        .toList()
      ..shuffle(_rng);

    if (decodable.length >= 3) {
      path.add(Activity(
        mode: GameMode.wordBuilder,
        targetSkillId: 'blend',
        itemIds: decodable.take(3).map((w) => w.id).toList(),
      ));
    }

    final coreLimit = _activitiesFor(targetMinutes) - 1;
    final fallbackTarget =
        taught.isEmpty ? (mayIntroduce ? nextNew : 'g:s') : taught.first;
    while (path.length < coreLimit) {
      path.add(Activity(
        mode: GameMode.soundDetective,
        targetSkillId: fallbackTarget,
        tier: byId[fallbackTarget]?.difficultyTier ?? 1,
        isEasyWin: true,
      ));
    }

    // Reserve the final activity before trimming. A closing game must never be
    // silently cut off by reviews or new-material activities earlier in the
    // session. Its words come from knowledge that existed before this session;
    // the first lesson is the only exception because no prior skill exists.
    final extension = _dailyExtension(
      decodable: safeDecodable,
      taught: taught,
      traceTarget:
          taught.isEmpty ? (mayIntroduce ? nextNew : 'g:s') : taught.last,
    );

    final trimmed = path.take(coreLimit).toList()..add(extension);
    if (trimmed.isNotEmpty) {
      trimmed[trimmed.length - 1] = trimmed.last.copyWith(isEasyWin: true);
    }
    return trimmed;
  }

  int _activitiesFor(int minutes) => (minutes / 3).round().clamp(3, 5);

  Activity _dailyExtension({
    required List<Word> decodable,
    required Set<String> taught,
    required String traceTarget,
  }) {
    switch (_clock().day % 4) {
      case 1:
        if (decodable.length >= 2) {
          return Activity(
            mode: GameMode.readSentence,
            targetSkillId: 'sentence',
            itemIds: decodable.take(2).map((w) => w.id).toList(),
            content: ActivityContent.words(
              wordIds: decodable.take(2).map((w) => w.id).toList(),
            ),
          );
        }
        return Activity(mode: GameMode.traceWrite, targetSkillId: traceTarget);
      case 2:
        if (decodable.length >= 3) {
          return Activity(
            mode: GameMode.spellingPicnic,
            targetSkillId: 'spelling',
            itemIds: decodable.take(3).map((w) => w.id).toList(),
            content: ActivityContent.words(
              wordIds: decodable.take(3).map((w) => w.id).toList(),
            ),
          );
        }
        return Activity(mode: GameMode.traceWrite, targetSkillId: traceTarget);
      case 3:
        if (gardenFriendsStory.isAvailable(taught)) {
          return const Activity(
            mode: GameMode.miniStory,
            targetSkillId: 'story:garden-friends',
            content: ActivityContent.story(storyId: 'story:garden-friends'),
          );
        }
        return Activity(mode: GameMode.traceWrite, targetSkillId: traceTarget);
      default:
        return Activity(mode: GameMode.traceWrite, targetSkillId: traceTarget);
    }
  }
}
