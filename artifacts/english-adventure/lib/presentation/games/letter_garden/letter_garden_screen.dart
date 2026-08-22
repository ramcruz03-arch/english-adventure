import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/praise.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/grapheme.dart';
import '../../../domain/entities/word.dart';
import '../../shared/big_button.dart';
import '../../shared/guide.dart';
import '../../shared/sound_stone.dart';
import '../../shared/support_ladder.dart';
import '../../shared/word_illustration.dart';

/// GAME A - Letter Garden.
/// One sound. Six pictures. Tap the ones that begin with it, and they bloom.
///
/// Note what is NOT here: no score, no timer, no counter, no red, no buzzer,
/// no way to lose. `Finish` is enabled from the first second.
class LetterGardenScreen extends ConsumerStatefulWidget {
  const LetterGardenScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;
  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<LetterGardenScreen> createState() => _LetterGardenScreenState();
}

class _LetterGardenScreenState extends ConsumerState<LetterGardenScreen> {
  late final Grapheme _target;
  late final List<Word> _tiles;
  late final Set<String> _correctIds;

  final _progress = ItemProgress();
  final _frustration = FrustrationWatcher();
  final _found = <String>{};
  final _dimmed = <String>{};
  String? _glowing;
  String _line = '';
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentRepositoryProvider);
    _target = content.grapheme(widget.activity.targetSkillId)!;
    _tiles = widget.activity.itemIds
        .map(content.word)
        .whereType<Word>()
        .toList();
    _correctIds = widget.activity.correctIds.toSet();
    _line = 'Tap everything that starts with ${_target.phoneme}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayTarget());
  }

  void _sayTarget({double? rate}) {
    ref.read(speechProvider).speakPhoneme(_target.ttsFallback,
        rate: rate ?? _target.ttsRate);
  }

  Future<void> _onTileTap(Word word) async {
    if (_found.contains(word.id)) return;
    _frustration.recordTap();

    final speech = ref.read(speechProvider);

    if (_correctIds.contains(word.id)) {
      setState(() {
        _found.add(word.id);
        _glowing = null;
        _line = Praise.pick(Praise.success);
      });
      await HapticFeedback.lightImpact();
      await speech.speak(word.text);
      _frustration.recordOutcome(true);

      if (_found.length == _correctIds.length) {
        _progress.solved = true;
        await _finish();
      }
      return;
    }

    // A miss. The tile wobbles, nothing is marked, nothing is taken away.
    _progress.misses++;
    _frustration.recordOutcome(false);

    setState(() => _line = _progress.guideLine);

    switch (_progress.support) {
      case SupportLevel.hint:
        _sayTarget(rate: 0.25); // slower, clearer
        setState(() {
          _dimmed.addAll(_tiles
              .where((w) => !_correctIds.contains(w.id) && w.id != word.id)
              .take(2)
              .map((w) => w.id));
        });
      case SupportLevel.demonstrate:
        final show = _tiles.firstWhere((w) => _correctIds.contains(w.id) && !_found.contains(w.id));
        setState(() => _glowing = show.id);
        await speech.speak('${_target.phoneme}... ${show.text}');
      case SupportLevel.none:
        break;
    }

    if (_frustration.shouldOfferBreak) await _offerBreak();
  }

  Future<void> _offerBreak() async {
    final rest = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Tokens.paper,
        content: AnilGuide(size: 64, line: Praise.pick(Praise.offerBreak)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep playing', style: TextStyle(fontSize: 20))),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: Tokens.leaf),
              child: const Text('Yes please', style: TextStyle(fontSize: 20))),
        ],
      ),
    );
    _frustration.reset();
    if (rest == true && mounted) await _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await ref.read(recordAttemptProvider)(
      childId: ref.read(activeChildProvider),
      sessionId: widget.sessionId,
      skillId: _target.id,
      skillType: 'grapheme',
      mode: GameMode.letterGarden,
      outcome: _progress.outcome,
      hintsUsed: _progress.misses,
      attemptKey: '${widget.activityKey}:finish',
    );
    if (mounted) widget.onDone(_progress.outcome);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ref.watch(readingPrefsProvider).reduceMotion;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            children: [
              AnilGuide(size: 60, line: _line),
              const SizedBox(height: 12),
              SoundStone(
                letter: _target.letters,
                reduceMotion: reduceMotion,
                onTap: _sayTarget,
              ),
              const SizedBox(height: 12),
              ReplayButton(onPressed: _sayTarget),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: _tiles
                      .map((w) => _PictureTile(
                            word: w,
                            found: _found.contains(w.id),
                            dimmed: _dimmed.contains(w.id),
                            glowing: _glowing == w.id,
                            onTap: () => _onTileTap(w),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 8),
              // Always available. The child may leave any activity at any time
              // and still keeps the star.
              BigButton(
                label: 'Finish',
                icon: Icons.check_rounded,
                colour: Tokens.marigold,
                onPressed: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PictureTile extends StatelessWidget {
  const _PictureTile({
    required this.word,
    required this.found,
    required this.dimmed,
    required this.glowing,
    required this.onTap,
  });

  final Word word;
  final bool found;
  final bool dimmed;
  final bool glowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // No visible text label: a label would let the child match letters
      // instead of listening for the sound.
      label: found ? '${word.text}, found' : 'picture',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: dimmed ? 0.32 : 1,
        child: GestureDetector(
          onTap: dimmed ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: BoxDecoration(
              color: found ? Tokens.leafLight : Colors.white,
              borderRadius: BorderRadius.circular(Tokens.radius),
              border: Border.all(
                color: glowing ? Tokens.marigold : Tokens.paperDeep,
                width: glowing ? 5 : 2,
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                WordIllustration(word: word, size: 58),
                if (found)
                  const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.local_florist_rounded,
                          color: Tokens.leaf, size: 26),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
