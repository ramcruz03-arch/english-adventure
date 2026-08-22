import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/praise.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/word.dart';
import '../../../domain/content/mini_story.dart';
import '../../shared/big_button.dart';
import '../../shared/guide.dart';
import '../../shared/word_illustration.dart';

/// GAME D — Read Sentence.
/// The child hears a short decodable sentence and reads it at their own pace.
class ReadSentenceScreen extends ConsumerStatefulWidget {
  const ReadSentenceScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.words,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;
  final List<Word> words;
  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<ReadSentenceScreen> createState() => _ReadSentenceScreenState();
}

class _ReadSentenceScreenState extends ConsumerState<ReadSentenceScreen> {
  bool _ready = false;
  bool _saving = false;

  String get _sentence => widget.words.map((word) => word.text).join(' ');

  void _speak() => ref.read(speechProvider).speak(_sentence);

  Future<void> _finish() async {
    if (_saving) return;
    if (_ready) {
      widget.onDone(1.0);
      return;
    }
    setState(() => _saving = true);
    await ref.read(progressRepositoryProvider).logAttempt(
          childId: ref.read(activeChildProvider),
          sessionId: widget.sessionId,
          skillId: widget.activity.targetSkillId,
          mode: GameMode.readSentence.name,
          outcome: 1.0,
          hintsUsed: 0,
          attemptKey: '${widget.activityKey}:finish',
        );
    if (mounted) {
      setState(() {
        _ready = true;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.gutter),
            child: Column(
              children: [
                AnilGuide(
                  size: 68,
                  line: _ready
                      ? Praise.pick(Praise.success)
                      : 'Listen, then read the sentence aloud',
                ),
                const Spacer(),
                Semantics(
                  label: 'Sentence: $_sentence',
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 12,
                    children: widget.words
                        .map(
                          (word) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(Tokens.radius),
                              border: Border.all(
                                color: _ready ? Tokens.leaf : Tokens.paperDeep,
                                width: 3,
                              ),
                            ),
                            child: Text(
                              word.text,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 28),
                ReplayButton(onPressed: _speak, label: 'Hear the sentence'),
                const Spacer(),
                BigButton(
                  label: _saving
                      ? 'One moment'
                      : (_ready ? 'Continue' : 'I read it'),
                  icon: _ready
                      ? Icons.arrow_forward_rounded
                      : Icons.check_rounded,
                  colour: Tokens.marigold,
                  onPressed: _saving ? () {} : _finish,
                ),
              ],
            ),
          ),
        ),
      );
}

/// GAME E — Mini Story.
/// A tiny two-page story gives reading a meaningful reason without testing it.
class MiniStoryScreen extends ConsumerStatefulWidget {
  const MiniStoryScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.story,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;
  final MiniStory story;
  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<MiniStoryScreen> createState() => _MiniStoryScreenState();
}

class _MiniStoryScreenState extends ConsumerState<MiniStoryScreen> {
  int _page = 0;
  bool _saving = false;

  MiniStoryPage get _pageContent => widget.story.pages[_page];

  Future<void> _next() async {
    if (_saving) return;
    if (_page < widget.story.pages.length - 1) {
      setState(() => _page += 1);
      return;
    }
    setState(() => _saving = true);
    await ref.read(progressRepositoryProvider).logAttempt(
          childId: ref.read(activeChildProvider),
          sessionId: widget.sessionId,
          skillId: widget.activity.targetSkillId,
          mode: GameMode.miniStory.name,
          outcome: 1.0,
          hintsUsed: 0,
          attemptKey: '${widget.activityKey}:finish',
        );
    if (mounted) widget.onDone(1.0);
  }

  void _speak() => ref.read(speechProvider).speak(_pageContent.text);

  @override
  Widget build(BuildContext context) {
    final illustration = ref
        .read(contentRepositoryProvider)
        .word(_pageContent.illustrationWordId);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            children: [
              const AnilGuide(
                  size: 68, line: 'Let’s read a little story together'),
              const Spacer(),
              if (illustration != null)
                WordIllustration(word: illustration, size: 96)
              else
                const Icon(Icons.park_rounded, size: 96, color: Tokens.leaf),
              const SizedBox(height: 18),
              Text(_pageContent.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              ReplayButton(onPressed: _speak, label: 'Hear this page'),
              const Spacer(),
              BigButton(
                label: _saving
                    ? 'One moment'
                    : (_page == widget.story.pages.length - 1
                        ? 'Finish story'
                        : 'Next page'),
                icon: _page == widget.story.pages.length - 1
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _saving ? () {} : _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// GAME F — Spelling Picnic.
/// Tap-to-place letters keep spelling accessible when dragging is difficult.
class SpellingPicnicScreen extends ConsumerStatefulWidget {
  const SpellingPicnicScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.words,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;
  final List<Word> words;
  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<SpellingPicnicScreen> createState() =>
      _SpellingPicnicScreenState();
}

class _SpellingPicnicScreenState extends ConsumerState<SpellingPicnicScreen> {
  int _index = 0;
  List<String> _picked = [];
  late List<String> _letters;
  String _line = 'Listen, then build the word';
  bool _busy = false;
  int _misses = 0;

  Word get _word => widget.words[_index];

  @override
  void initState() {
    super.initState();
    _resetWord();
  }

  void _resetWord() {
    _picked = [];
    _letters = [..._word.text.split('')]..shuffle();
    _misses = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  void _speak() => ref.read(speechProvider).speak(_word.text);

  void _pick(String letter) {
    if (_busy || _picked.length >= _word.text.length) return;
    setState(() {
      _picked = [..._picked, letter];
      _letters = [..._letters]..remove(letter);
    });
  }

  Future<void> _check() async {
    if (_busy || _picked.length != _word.text.length) {
      setState(() => _line = 'Choose a letter for each space');
      return;
    }
    final complete = _picked.join() == _word.text;
    if (!complete) {
      await ref.read(recordAttemptProvider)(
        childId: ref.read(activeChildProvider),
        sessionId: widget.sessionId,
        skillId: _word.id,
        skillType: 'word',
        mode: GameMode.spellingPicnic,
        outcome: 0.0,
        hintsUsed: 1,
        attemptKey: '${widget.activityKey}:word:$_index:miss:$_misses',
      );
      _misses += 1;
      if (_misses >= 3) {
        setState(() {
          _busy = true;
          _line = 'We can finish this picnic together.';
        });
        await ref.read(speechProvider).speak(_word.text);
        if (mounted) widget.onDone(0.0);
        return;
      }
      setState(() {
        if (_misses == 2) {
          _line = 'I started it. Let’s finish together.';
          _picked = [_word.text[0]];
          _letters = _word.text.split('').sublist(1)..shuffle();
        } else {
          _line = 'Let’s hear it again, then try together.';
          _picked = [];
          _letters = [..._word.text.split('')]..shuffle();
        }
      });
      await HapticFeedback.lightImpact();
      _speak();
      return;
    }

    setState(() {
      _busy = true;
      _line = Praise.pick(Praise.success);
    });
    await ref.read(recordAttemptProvider)(
      childId: ref.read(activeChildProvider),
      sessionId: widget.sessionId,
      skillId: _word.id,
      skillType: 'word',
      mode: GameMode.spellingPicnic,
      outcome: 1.0,
      attemptKey: '${widget.activityKey}:word:$_index:finish',
    );
    await ref.read(speechProvider).speak(_word.text);
    if (!mounted) return;
    if (_index == widget.words.length - 1) {
      widget.onDone(1.0);
    } else {
      setState(() {
        _index += 1;
        _busy = false;
        _line = 'Listen, then build the word';
        _resetWord();
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Tokens.gutter),
            child: Column(
              children: [
                AnilGuide(size: 68, line: _line),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _speak,
                  child: WordIllustration(word: _word, size: 108),
                ),
                const SizedBox(height: 12),
                ReplayButton(onPressed: _speak, label: 'Hear the word'),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _word.text.length; i++)
                      Container(
                        width: 54,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Tokens.paperDeep, width: 3),
                        ),
                        child: Text(
                          i < _picked.length ? _picked[i] : '',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: _letters
                      .map(
                        (letter) => SizedBox(
                          width: 64,
                          height: 64,
                          child: FilledButton(
                            onPressed: () => _pick(letter),
                            style: FilledButton.styleFrom(
                              backgroundColor: Tokens.leaf,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(letter.toUpperCase(),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(color: Colors.white)),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const Spacer(),
                BigButton(
                  label: 'Check my word',
                  icon: Icons.check_rounded,
                  colour: Tokens.marigold,
                  onPressed: _check,
                ),
              ],
            ),
          ),
        ),
      );
}
