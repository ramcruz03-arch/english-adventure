import 'package:english_adventure/domain/entities/activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a word activity keeps its full payload through a checkpoint', () {
    const activity = Activity(
      mode: GameMode.spellingPicnic,
      targetSkillId: 'spelling',
      itemIds: ['w:map', 'w:pin'],
      correctIds: ['w:map'],
      content: ActivityContent.words(wordIds: ['w:map', 'w:pin']),
      tier: 2,
      isEasyWin: true,
    );

    final restored = Activity.fromJson(activity.toJson());

    expect(restored.mode, GameMode.spellingPicnic);
    expect(restored.targetSkillId, 'spelling');
    expect(restored.wordIds, ['w:map', 'w:pin']);
    expect(restored.correctIds, ['w:map']);
    expect(restored.tier, 2);
    expect(restored.isEasyWin, isTrue);
  });

  test('a story activity keeps its named story through a checkpoint', () {
    const activity = Activity(
      mode: GameMode.miniStory,
      targetSkillId: 'story:garden-friends',
      content: ActivityContent.story(storyId: 'story:garden-friends'),
    );

    final restored = Activity.fromJson(activity.toJson());

    expect(restored.mode, GameMode.miniStory);
    expect(restored.storyId, 'story:garden-friends');
    expect(restored.content?.isValid, isTrue);
  });
}