import 'dart:math';

import 'package:english_adventure/data/content/asset_content_repository.dart';
import 'package:english_adventure/domain/content/mini_story.dart';
import 'package:english_adventure/domain/entities/activity.dart';
import 'package:english_adventure/domain/entities/grapheme.dart';
import 'package:english_adventure/domain/entities/skill_state.dart';
import 'package:english_adventure/domain/entities/word.dart';
import 'package:english_adventure/domain/entities/resumable_session.dart';
import 'package:english_adventure/domain/repositories/content_repository.dart';
import 'package:english_adventure/domain/repositories/progress_repository.dart';
import 'package:english_adventure/domain/usecases/build_daily_path.dart';
import 'package:flutter_test/flutter_test.dart';

class _Content implements ContentRepository {
  static const _ids = ['g:s', 'g:a', 'g:t', 'g:p', 'g:i', 'g:n', 'g:m', 'g:d'];

  @override
  List<String> get curriculumOrder => _ids;

  @override
  List<Grapheme> get graphemes => const [];

  @override
  List<Word> get words => const [
        Word(
          id: 'w:sat',
          text: 'sat',
          type: WordType.cvc,
          graphemeIds: ['g:s', 'g:a', 'g:t'],
        ),
        Word(
          id: 'w:pin',
          text: 'pin',
          type: WordType.cvc,
          graphemeIds: ['g:p', 'g:i', 'g:n'],
        ),
        Word(
          id: 'w:map',
          text: 'map',
          type: WordType.cvc,
          graphemeIds: ['g:m', 'g:a', 'g:p'],
        ),
      ];

  @override
  Grapheme? grapheme(String id) => null;

  @override
  Future<void> load() async {}

  @override
  Word? word(String id) {
    for (final word in words) {
      if (word.id == id) return word;
    }
    return null;
  }
}

class _Progress implements ProgressRepository {
  _Progress(this.states);

  final List<SkillState> states;

  @override
  Future<List<SkillState>> allSkills(String childId) async => states;

  @override
  Future<void> endSession(
    String sessionId, {
    required int seconds,
    required int activities,
    required int stars,
    required String reason,
  }) async {}

  @override
  Future<double> lastSessionAccuracy(String childId) async => 1.0;

  @override
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
  }) async =>
      true;

  @override
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
  }) async =>
      true;

  @override
  Future<void> saveSkill(SkillState state) async {}

  @override
  Future<void> saveTracingSample({
    required String childId,
    required String glyphId,
    required double coverage,
    required double meanDeviation,
    required bool strokeOrderOk,
    String? sampleKey,
  }) async {}

  @override
  Future<void> deleteAllData() async {}

  @override
  Future<SkillState> skill(
          String childId, String skillId, String skillType) async =>
      SkillState(childId: childId, skillId: skillId, skillType: skillType);

  @override
  Future<String> startSession(String childId,
          {List<Activity> path = const []}) async =>
      'session';

  @override
  Future<ResumableSession?> unfinishedSession(String childId) async => null;

  @override
  Future<void> saveSessionPlan(String sessionId, List<Activity> path) async {}

  @override
  Future<void> saveSessionProgress(String sessionId,
      {required int currentActivity, required int stars}) async {}

  @override
  Future<bool> advanceSession(String sessionId,
          {required int expectedActivity,
          required int nextActivity,
          required int stars}) async =>
      true;
}

Future<Activity> _extensionForDay(int day) async {
  final states = _Content._ids
      .map(
        (id) => SkillState(
          childId: 'child',
          skillId: id,
          skillType: 'grapheme',
          status: SkillStatus.learning,
        ),
      )
      .toList();
  final path = await BuildDailyPath(
    _Content(),
    _Progress(states),
    rng: Random(4),
    clock: () => DateTime(2026, 1, day),
  )(childId: 'child');
  return path.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('word payloads are retained when an activity becomes an easy win', () {
    const payload = ActivityContent.words(wordIds: ['w:sat', 'w:pin']);
    const activity = Activity(
      mode: GameMode.readSentence,
      targetSkillId: 'sentence',
      content: payload,
    );

    final completed = activity.copyWith(isEasyWin: true);

    expect(payload.isValid, isTrue);
    expect(completed.wordIds, ['w:sat', 'w:pin']);
    expect(completed.isEasyWin, isTrue);
  });

  test('the daily closing games receive typed, playable content', () async {
    final sentence = await _extensionForDay(1);
    final spelling = await _extensionForDay(2);
    final story = await _extensionForDay(3);

    expect(sentence.mode, GameMode.readSentence);
    expect(sentence.content?.kind, ActivityContentKind.wordSet);
    expect(sentence.wordIds, isNotEmpty);
    expect(sentence.isEasyWin, isTrue);

    expect(spelling.mode, GameMode.spellingPicnic);
    expect(spelling.content?.kind, ActivityContentKind.wordSet);
    expect(spelling.wordIds, isNotEmpty);
    expect(spelling.isEasyWin, isTrue);

    expect(story.mode, GameMode.miniStory);
    expect(story.storyId, gardenFriendsStory.id);
    expect(miniStoryForId(story.storyId!), same(gardenFriendsStory));
    expect(story.isEasyWin, isTrue);
  });

  test('a new sound without three initial pictures skips Letter Garden',
      () async {
    final states = [
      const SkillState(
        childId: 'child',
        skillId: 'g:s',
        skillType: 'grapheme',
        status: SkillStatus.learning,
      ),
    ];
    final path = await BuildDailyPath(
      _Content(),
      _Progress(states),
      rng: Random(4),
      clock: () => DateTime(2026, 1, 1),
    )(childId: 'child');

    expect(path.any((a) => a.mode == GameMode.letterGarden), isFalse);
    expect(
      path.any(
          (a) => a.mode == GameMode.soundDetective && a.targetSkillId == 'g:a'),
      isTrue,
    );
  });

  test('every scheduled activity resolves to playable bundled content',
      () async {
    final content = AssetContentRepository();
    await content.load();

    for (var taughtCount = 0;
        taughtCount <= content.curriculumOrder.length;
        taughtCount++) {
      final states = content.curriculumOrder
          .take(taughtCount)
          .map(
            (id) => SkillState(
              childId: 'child',
              skillId: id,
              skillType: 'grapheme',
              status: SkillStatus.mastered,
            ),
          )
          .toList();

      for (var day = 1; day <= 4; day++) {
        final path = await BuildDailyPath(
          content,
          _Progress(states),
          rng: Random(taughtCount * 10 + day),
          clock: () => DateTime(2026, 1, day),
        )(childId: 'child');

        expect(path, isNotEmpty);
        for (final activity in path) {
          switch (activity.mode) {
            case GameMode.letterGarden:
              final matching = content.words
                  .where((word) =>
                      word.graphemeIds.isNotEmpty &&
                      word.graphemeIds.first == activity.targetSkillId)
                  .length;
              final other = content.words
                  .where((word) =>
                      word.graphemeIds.isNotEmpty &&
                      word.graphemeIds.first != activity.targetSkillId)
                  .length;
              expect(matching, greaterThanOrEqualTo(3));
              expect(other, greaterThanOrEqualTo(3));
            case GameMode.soundDetective:
            case GameMode.traceWrite:
              expect(content.grapheme(activity.targetSkillId), isNotNull);
            case GameMode.wordBuilder:
            case GameMode.readSentence:
            case GameMode.spellingPicnic:
              expect(activity.wordIds, isNotEmpty);
              for (final wordId in activity.wordIds) {
                expect(content.word(wordId), isNotNull);
              }
            case GameMode.miniStory:
              final story = miniStoryForId(activity.storyId!);
              expect(story, isNotNull);
              expect(story!.pages, isNotEmpty);
              for (final page in story.pages) {
                expect(content.word(page.illustrationWordId), isNotNull);
              }
          }
        }
      }
    }
  });
}
