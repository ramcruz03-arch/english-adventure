import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/praise.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/word.dart';
import '../../../domain/usecases/word_slots.dart';
import '../../shared/big_button.dart';
import '../../shared/guide.dart';
import '../../shared/word_illustration.dart';
import '../../shared/support_ladder.dart';

/// GAME C — Word Builder.
/// A picture. Empty slots. Loose letters. Build the word, then hear it blend.
///
/// Both input methods work: drag a tile onto a slot, or simply tap it and it
/// flies to the next slot itself. That is not a nicety — dragging is genuinely
/// hard for five-year-olds and for any child with weak fine motor control, and
/// a child who cannot drag must not be locked out of spelling.
///
/// The pay-off is the blend: each letter lights and sounds in turn, then the
/// whole word is swept and spoken. That sweep is the moment the child sees
/// three separate sounds become one word, which is the entire point of phonics.
class WordBuilderScreen extends ConsumerStatefulWidget {
  const WordBuilderScreen({
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
  ConsumerState<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends ConsumerState<WordBuilderScreen> {
  late Word _word;
  late SlotBoard _board;
  late List<String> _tray;

  final _outcomes = <double>[];
  final _frustration = FrustrationWatcher();
  var _index = 0;
  var _item = ItemProgress();
  var _line = '';
  int? _blendingSlot;
  bool _busy = false;
  DateTime _shownAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  void _loadWord() {
    _word = widget.words[_index];
    _board = SlotBoard(_word.text.split(''));
    _tray = [..._board.targetLetters]..shuffle();
    _item = ItemProgress();
    _blendingSlot = null;
    _line = 'Build the word.';
    _shownAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sayWord());
  }

  void _sayWord() => ref.read(speechProvider).speak(_word.text);

  /// Sound of the letter at [slot], falling back to the letter itself when the
  /// content pack has no grapheme mapping for this word.
  void _sayLetterSound(int slot) {
    final content = ref.read(contentRepositoryProvider);
    final ids = _word.graphemeIds;
    if (ids.length == _board.targetLetters.length) {
      final g = content.grapheme(ids[slot]);
      if (g != null) {
        ref.read(speechProvider).speakPhoneme(g.ttsFallback);
        return;
      }
    }
    ref.read(speechProvider).speakPhoneme(_board.targetLetters[slot]);
  }

  Future<void> _tryLetter(String letter) async {
    if (_busy) return;
    _frustration.recordTap();

    final slot = _board.place(letter);

    if (slot != null) {
      setState(() {
        _tray.remove(letter);
        _line = _board.isComplete ? Praise.pick(Praise.success) : 'Good — keep going.';
      });
      await HapticFeedback.selectionClick();
      _sayLetterSound(slot);
      _frustration.recordOutcome(true);

      if (_board.isComplete) {
        _item.solved = true;
        await _blend();
      }
      return;
    }

    // Wrong slot for this letter. It goes back to the tray untouched.
    _item.misses++;
    _frustration.recordOutcome(false);
    setState(() => _line = _item.guideLine);

    switch (_item.support) {
      case SupportLevel.hint:
        // Say the sound the empty slot is waiting for.
        final active = _board.activeSlot;
        if (active != null) _sayLetterSound(active);
      case SupportLevel.demonstrate:
        final filled = _board.placeCorrectOne();
        if (filled != null) {
          setState(() => _tray.remove(_board.targetLetters[filled]));
          _sayLetterSound(filled);
          if (_board.isComplete) {
            _item.solved = true;
            await _blend();
            return;
          }
        }
      case SupportLevel.none:
        break;
    }

    if (_frustration.shouldOfferBreak) await _offerBreak();
  }

  /// The blend sweep: each sound in turn, then the whole word.
  Future<void> _blend() async {
    _busy = true;
    final speech = ref.read(speechProvider);
    final reduceMotion = ref.read(readingPrefsProvider).reduceMotion;

    for (var i = 0; i < _board.targetLetters.length; i++) {
      if (!mounted) return;
      setState(() => _blendingSlot = i);
      _sayLetterSound(i);
      await Future.delayed(Duration(milliseconds: reduceMotion ? 420 : 620));
    }
    if (!mounted) return;
    setState(() {
      _blendingSlot = null;
      _line = Praise.pick(Praise.success);
    });
    await speech.speak(_word.text);
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 700));
    await _commitWord();
  }

  Future<void> _commitWord() async {
    await ref.read(recordAttemptProvider)(
      childId: ref.read(activeChildProvider),
      sessionId: widget.sessionId,
      skillId: _word.id,
      skillType: 'word',
      mode: GameMode.wordBuilder,
      outcome: _item.outcome,
      hintsUsed: _item.misses,
      chosenValue: _word.text,
      responseMs: DateTime.now().difference(_shownAt).inMilliseconds,
      attemptKey: '${widget.activityKey}:word:$_index',
    );
    _outcomes.add(_item.outcome);

    if (!mounted) return;
    _busy = false;
    if (_index + 1 >= widget.words.length) {
      _finish();
    } else {
      setState(() {
        _index++;
        _loadWord();
      });
    }
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
            child: const Text('Keep playing', style: TextStyle(fontSize: 20)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Tokens.leaf),
            child: const Text('Yes please', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
    );
    _frustration.reset();
    if (rest == true && mounted) _finish();
  }

  void _finish() {
    final avg = _outcomes.isEmpty
        ? 0.0
        : _outcomes.reduce((a, b) => a + b) / _outcomes.length;
    widget.onDone(avg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            children: [
              AnilGuide(size: 56, line: _line),
              const SizedBox(height: 12),
              _PictureCard(word: _word, onTap: _sayWord),
              const SizedBox(height: 10),
              ReplayButton(onPressed: _sayWord, label: 'Hear the word'),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _board.placed.length; i++)
                    _Slot(
                      letter: _board.placed[i],
                      active: _board.activeSlot == i,
                      blending: _blendingSlot == i,
                      onAccept: _tryLetter,
                      onTap: () {
                        if (_board.placed[i] != null) _sayLetterSound(i);
                      },
                    ),
                ],
              ),
              const Spacer(),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: _tray
                    .map((l) => _LetterTile(
                          letter: l,
                          onTap: () => _tryLetter(l),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              BigButton(
                label: 'Finish',
                icon: Icons.check_rounded,
                colour: Tokens.marigold,
                onPressed: _busy ? () {} : _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({required this.word, required this.onTap});

  final Word word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'picture, tap to hear the word',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 168,
          height: 168,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Tokens.radius),
            border: Border.all(color: Tokens.paperDeep, width: 3),
          ),
          alignment: Alignment.center,
          child: WordIllustration(word: word, size: 88),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.letter,
    required this.active,
    required this.blending,
    required this.onAccept,
    required this.onTap,
  });

  final String? letter;
  final bool active;
  final bool blending;
  final void Function(String) onAccept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onAcceptWithDetails: (d) => onAccept(d.data),
      builder: (context, candidate, _) {
        final highlighted = active || candidate.isNotEmpty;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 7),
            width: 86,
            height: 106,
            decoration: BoxDecoration(
              color: blending ? Tokens.marigold.withValues(alpha: 0.28) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: blending
                    ? Tokens.marigold
                    : (highlighted ? Tokens.leaf : Tokens.paperDeep),
                width: highlighted || blending ? 4 : 3,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              letter ?? '',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 58, height: 1.0),
            ),
          ),
        );
      },
    );
  }
}

/// Draggable AND tappable. Tapping sends it to the next slot on its own.
class _LetterTile extends StatelessWidget {
  const _LetterTile({required this.letter, required this.onTap});

  final String letter;
  final VoidCallback onTap;

  Widget _face(BuildContext context, {bool floating = false}) => Container(
        width: 82,
        height: 96,
        decoration: BoxDecoration(
          color: floating ? Tokens.leafLight : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Tokens.paperDeep, width: 3),
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: Theme.of(context)
              .textTheme
              .displayLarge
              ?.copyWith(fontSize: 54, height: 1.0),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'letter $letter, tap to place it',
      child: GestureDetector(
        onTap: onTap,
        child: Draggable<String>(
          data: letter,
          feedback: Material(
            color: Colors.transparent,
            child: _face(context, floating: true),
          ),
          childWhenDragging: Opacity(opacity: 0.3, child: _face(context)),
          child: _face(context),
        ),
      ),
    );
  }
}
