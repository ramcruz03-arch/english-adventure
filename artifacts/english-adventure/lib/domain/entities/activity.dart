enum GameMode {
  letterGarden,
  soundDetective,
  wordBuilder,
  traceWrite,
  readSentence,
  miniStory,
  spellingPicnic,
}

/// The content contract carried by an activity.
///
/// Keeping the payload typed prevents a screen from having to guess whether an
/// ID is a word, a sentence set, or a story. [itemIds] remains on [Activity]
/// for compatibility with lesson packs created before these contracts existed;
/// new paths should populate [content].
enum ActivityContentKind { wordSet, story }

class ActivityContent {
  const ActivityContent.words({required this.wordIds})
      : kind = ActivityContentKind.wordSet,
        storyId = null;

  const ActivityContent.story({required this.storyId})
      : kind = ActivityContentKind.story,
        wordIds = const [];

  final ActivityContentKind kind;
  final List<String> wordIds;
  final String? storyId;

  bool get isValid => switch (kind) {
        ActivityContentKind.wordSet => wordIds.isNotEmpty,
        ActivityContentKind.story => storyId != null && storyId!.isNotEmpty,
      };
}

/// One 2-3 minute unit of a session. Built at runtime by BuildDailyPath,
/// or read straight from a lesson JSON file.
class Activity {
  const Activity({
    required this.mode,
    required this.targetSkillId,
    this.itemIds = const [],
    this.correctIds = const [],
    this.content,
    this.tier = 1,
    this.isEasyWin = false,
  });

  final GameMode mode;
  final String targetSkillId;

  /// Legacy word payload. Prefer [content] for newly-created activities.
  final List<String> itemIds;
  final List<String> correctIds;
  final ActivityContent? content;
  final int tier;

  /// Sessions always end on something the child can already do.
  final bool isEasyWin;

  /// IDs consumed by word-based games, regardless of which contract produced
  /// them.
  List<String> get wordIds =>
      content?.kind == ActivityContentKind.wordSet ? content!.wordIds : itemIds;

  String? get storyId =>
      content?.kind == ActivityContentKind.story ? content!.storyId : null;

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'targetSkillId': targetSkillId,
        'itemIds': itemIds,
        'correctIds': correctIds,
        'tier': tier,
        'isEasyWin': isEasyWin,
        'content': content == null
            ? null
            : {
                'kind': content!.kind.name,
                'wordIds': content!.wordIds,
                'storyId': content!.storyId,
              },
      };

  factory Activity.fromJson(Map<String, dynamic> json) {
    final rawContent = json['content'];
    ActivityContent? parsedContent;
    if (rawContent is Map) {
      final kind = rawContent['kind'] as String?;
      if (kind == ActivityContentKind.wordSet.name) {
        parsedContent = ActivityContent.words(
          wordIds: List<String>.from(rawContent['wordIds'] as List? ?? const []),
        );
      } else if (kind == ActivityContentKind.story.name) {
        final storyId = rawContent['storyId'] as String?;
        if (storyId != null && storyId.isNotEmpty) {
          parsedContent = ActivityContent.story(storyId: storyId);
        }
      }
    }
    return Activity(
      mode: GameMode.values.byName(json['mode'] as String),
      targetSkillId: json['targetSkillId'] as String,
      itemIds: List<String>.from(json['itemIds'] as List? ?? const []),
      correctIds: List<String>.from(json['correctIds'] as List? ?? const []),
      content: parsedContent,
      tier: (json['tier'] as num?)?.toInt() ?? 1,
      isEasyWin: json['isEasyWin'] as bool? ?? false,
    );
  }

  Activity copyWith({bool? isEasyWin, ActivityContent? content}) => Activity(
        mode: mode,
        targetSkillId: targetSkillId,
        itemIds: itemIds,
        correctIds: correctIds,
        content: content ?? this.content,
        tier: tier,
        isEasyWin: isEasyWin ?? this.isEasyWin,
      );
}
