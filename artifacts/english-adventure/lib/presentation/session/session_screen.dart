import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/audio/praise.dart';
import '../../domain/content/mini_story.dart';
import '../../domain/entities/activity.dart';
import '../../domain/entities/grapheme.dart';
import '../../domain/entities/skill_state.dart';
import '../../domain/entities/word.dart';
import '../../domain/entities/resumable_session.dart';
import '../../domain/repositories/content_repository.dart';
import '../../domain/usecases/select_distractors.dart';
import '../games/letter_garden/letter_garden_screen.dart';
import '../games/sound_detective/sound_detective_screen.dart';
import '../games/word_builder/word_builder_screen.dart';
import '../games/trace_write/trace_write_screen.dart';
import '../games/remaining_games/remaining_games_screen.dart';
import '../shared/big_button.dart';
import '../shared/guide.dart';

/// Runs today's path: 3–5 activities, then the Reward Room.
///
/// This is the only place that knows how to turn an abstract Activity into
/// concrete items. Games receive finished item sets and contain no selection
/// logic, which is what keeps the pedagogy in one testable place.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, this.resumeSession});

  final ResumableSession? resumeSession;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen>
    with WidgetsBindingObserver {
  List<Activity> _path = [];
  String? _sessionId;
  int _index = 0;
  int _stars = 0;
  int _childLevel = 1;
  List<Grapheme> _taught = [];
  DateTime _startedAt = DateTime.now();
  bool _loading = true;
  bool _advancing = false;
  bool _ending = false;

  static const _roundsPerActivity = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _start() async {
    final childId = ref.read(activeChildProvider);
    final content = ref.read(contentRepositoryProvider);
    final progress = ref.read(progressRepositoryProvider);

    final states = await progress.allSkills(childId);

    final touched = states
        .where((s) =>
            s.skillType == 'grapheme' && s.status != SkillStatus.untouched)
        .map((s) => s.skillId)
        .toSet();
    final mastered = states
        .where((s) =>
            s.skillType == 'grapheme' && s.status == SkillStatus.mastered)
        .length;

    final saved = widget.resumeSession;
    late String sessionId;
    late List<Activity> path;
    var resumeIndex = 0;
    var resumeStars = 0;
    var startedAt = DateTime.now();

    if (saved != null &&
        saved.childId == childId &&
        saved.currentActivity < saved.path.length) {
      sessionId = saved.id;
      path = saved.path;
      resumeIndex = saved.currentActivity;
      resumeStars = saved.stars;
      startedAt = saved.startedAt;
    } else {
      path = await ref.read(buildDailyPathProvider)(childId: childId);
      path = path.map((a) => _populate(a, content)).toList();
      sessionId = await progress.startSession(childId, path: path);
      // Home may already have cached "no unfinished session". Refresh it now
      // so returning from this screen always offers this same adventure.
      ref.invalidate(unfinishedSessionProvider(childId));
    }

    if (!mounted) return;
    setState(() {
      _sessionId = sessionId;
      _path = path;
      _index = resumeIndex;
      _stars = resumeStars;
      _taught = content.graphemes.where((g) => touched.contains(g.id)).toList();
      // Level gates distractor choice. Below 3, confusable pairs stay apart.
      _childLevel = mastered >= 8 ? 3 : (mastered >= 4 ? 2 : 1);
      _startedAt = startedAt;
      _loading = false;
    });
  }

  /// Letter Garden needs 3 words beginning with the target sound and 3 that
  /// do not — all drawn from words the child can already handle.
  Activity _populate(Activity a, ContentRepository content) {
    if (a.mode != GameMode.letterGarden || a.itemIds.isNotEmpty) return a;

    final g = content.grapheme(a.targetSkillId);
    if (g == null) return a;

    final correct = content.words
        .where((w) => w.graphemeIds.isNotEmpty && w.graphemeIds.first == g.id)
        .take(3)
        .toList();
    final others = content.words
        .where((w) => w.graphemeIds.isNotEmpty && w.graphemeIds.first != g.id)
        .take(3)
        .toList();

    // Older lesson packs may still contain a Letter Garden activity for a
    // sound that has fewer than three matching pictures. Route it to the
    // sound game rather than showing an incomplete picture grid.
    if (correct.length < 3 || others.length < 3) {
      return Activity(
        mode: GameMode.soundDetective,
        targetSkillId: a.targetSkillId,
        tier: a.tier,
        isEasyWin: a.isEasyWin,
      );
    }

    final all = [...correct, ...others]..shuffle();
    return Activity(
      mode: a.mode,
      targetSkillId: a.targetSkillId,
      itemIds: all.map((w) => w.id).toList(),
      correctIds: correct.map((w) => w.id).toList(),
      content: a.content,
      tier: a.tier,
      isEasyWin: a.isEasyWin,
    );
  }

  /// One choice set per round, target first. Reshuffled each round so the
  /// child cannot learn a position instead of a sound.
  List<List<Grapheme>> _buildRounds(Activity a) {
    final content = ref.read(contentRepositoryProvider);
    final target = content.grapheme(a.targetSkillId);
    if (target == null) return const [];

    // On the very first session there is nothing else taught yet, so fall back
    // to the next letters in curriculum order rather than showing one card.
    var pool = _taught.where((g) => g.id != target.id).toList();
    if (pool.length < 3) {
      pool = content.curriculumOrder
          .take(6)
          .map(content.grapheme)
          .whereType<Grapheme>()
          .where((g) => g.id != target.id)
          .toList();
    }

    return List.generate(_roundsPerActivity, (_) {
      final distractors = selectDistractors(
        target: target,
        taught: pool,
        tier: a.tier,
        childLevel: _childLevel,
      );
      return [target, ...distractors];
    });
  }

  Future<void> _next(int expectedIndex) async {
    if (_advancing || _sessionId == null || expectedIndex != _index) return;
    _advancing = true;
    final nextIndex = _index + 1;
    final nextStars = _stars + 1;
    final advanced = await ref.read(progressRepositoryProvider).advanceSession(
          _sessionId!,
          expectedActivity: expectedIndex,
          nextActivity: nextIndex,
          stars: nextStars,
        );
    if (!advanced) {
      _advancing = false;
      return;
    }
    if (!mounted) return;
    setState(() {
      _stars = nextStars; // a star for finishing, never for being right
      _index = nextIndex;
    });
    _advancing = false;
    if (_index >= _path.length) await _end('complete');
  }

  Future<void> _checkpoint() async {
    final id = _sessionId;
    if (id == null || _loading || _index >= _path.length) return;
    await ref.read(progressRepositoryProvider).saveSessionProgress(
          id,
          currentActivity: _index,
          stars: _stars,
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_checkpoint());
    }
  }

  Future<void> _end(String reason) async {
    if (_ending || _sessionId == null) return;
    _ending = true;
    await ref.read(progressRepositoryProvider).endSession(
          _sessionId!,
          seconds: DateTime.now().difference(_startedAt).inSeconds,
          activities: _index,
          stars: _stars,
          reason: reason,
        );
    ref.invalidate(unfinishedSessionProvider(ref.read(activeChildProvider)));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => RewardRoom(stars: _stars)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_index >= _path.length) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final activity = _path[_index];
    final activityIndex = _index;
    switch (activity.mode) {
      case GameMode.letterGarden:
        return LetterGardenScreen(
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.soundDetective:
        final rounds = _buildRounds(activity);
        if (rounds.isEmpty) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return SoundDetectiveScreen(
          key: ValueKey('sd_${_index}_${activity.targetSkillId}'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          rounds: rounds,
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.wordBuilder:
        final content = ref.read(contentRepositoryProvider);
        final words =
            activity.wordIds.map(content.word).whereType<Word>().toList();
        if (words.isEmpty) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return WordBuilderScreen(
          key: ValueKey('wb_$_index'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          words: words,
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.traceWrite:
        final content = ref.read(contentRepositoryProvider);
        final target = content.grapheme(activity.targetSkillId);
        if (target == null) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return TraceWriteScreen(
          key: ValueKey('tw_$_index'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          target: target,
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.readSentence:
        final content = ref.read(contentRepositoryProvider);
        final words =
            activity.wordIds.map(content.word).whereType<Word>().toList();
        if (words.isEmpty) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return ReadSentenceScreen(
          key: ValueKey('rs_$_index'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          words: words,
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.miniStory:
        final story = miniStoryForId(
          activity.storyId ?? activity.targetSkillId,
        );
        if (story == null || story.pages.isEmpty) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return MiniStoryScreen(
          key: ValueKey('ms_$_index'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          story: story,
          onDone: (_) => _next(activityIndex),
        );
      case GameMode.spellingPicnic:
        final content = ref.read(contentRepositoryProvider);
        final words =
            activity.wordIds.map(content.word).whereType<Word>().toList();
        if (words.isEmpty) {
          return _NotBuiltYet(
              mode: activity.mode, onSkip: () => _next(activityIndex));
        }
        return SpellingPicnicScreen(
          key: ValueKey('sp_$_index'),
          activity: activity,
          sessionId: _sessionId!,
          activityKey: '$activityIndex',
          words: words,
          onDone: (_) => _next(activityIndex),
        );
    }
  }
}

class _NotBuiltYet extends StatelessWidget {
  const _NotBuiltYet({required this.mode, required this.onSkip});

  final GameMode mode;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.gutter),
            child: Column(
              children: [
                const Spacer(),
                const AnilGuide(
                  size: 104,
                  line: 'This part of the adventure is growing.',
                ),
                const SizedBox(height: 28),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'You can come back to this garden path another day. '
                  'Your grown-up can see when it is ready.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const Spacer(),
                BigButton(
                  label: 'Continue today',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: onSkip,
                ),
              ],
            ),
          ),
        ),
      );

  String get _title {
    switch (mode) {
      case GameMode.readSentence:
        return 'Reading Meadow';
      case GameMode.miniStory:
        return 'Story Tree';
      case GameMode.spellingPicnic:
        return 'Spelling Picnic';
      default:
        return 'A new garden path';
    }
  }
}

class RewardRoom extends StatelessWidget {
  const RewardRoom({super.key, required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnilGuide(size: 96, line: Praise.pick(Praise.sessionEnd)),
              const SizedBox(height: 32),
              Wrap(
                spacing: 8,
                children: List.generate(
                  stars,
                  (_) => const Icon(Icons.star_rounded,
                      size: 64, color: Tokens.marigold),
                ),
              ),
              const Spacer(),
              BigButton(
                label: 'Back to the garden',
                icon: Icons.park_rounded,
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
