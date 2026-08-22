import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/audio/praise.dart';
import '../../../domain/entities/activity.dart';
import '../../../domain/entities/grapheme.dart';
import '../../shared/big_button.dart';
import '../../shared/guide.dart';
import '../../shared/support_ladder.dart';

/// GAME B — Sound Detective.
/// Anil plays a sound. Two to four letters are on the table. Which one makes it?
///
/// The whole game is an ear-to-eye mapping, so the sound is the hero and the
/// magnifying glass — not a small speaker icon in a corner — is the biggest
/// interactive thing on the screen. Replays are unlimited and never counted.
///
/// The distractors are chosen by `selectDistractors`, which is where the real
/// pedagogy lives: below level 3 a confusable pair (b/d, p/q, m/n) is never
/// allowed on the table at the same time. A child who cannot yet tell them
/// apart should not be asked to.
class SoundDetectiveScreen extends ConsumerStatefulWidget {
  const SoundDetectiveScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.rounds,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;

  /// Each round: the target grapheme first, then its distractors for that round.
  /// Pre-built by the session runner so this screen stays free of selection logic.
  final List<List<Grapheme>> rounds;

  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<SoundDetectiveScreen> createState() => _SoundDetectiveScreenState();
}

class _SoundDetectiveScreenState extends ConsumerState<SoundDetectiveScreen> {
  late Grapheme _target;
  late List<Grapheme> _choices;

  final _frustration = FrustrationWatcher();
  final _outcomes = <double>[];
  var _round = 0;
  var _item = ItemProgress();
  final _dimmed = <String>{};
  String? _glowing;
  String _line = '';
  DateTime _shownAt = DateTime.now();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _loadRound();
  }

  void _loadRound() {
    final set = widget.rounds[_round];
    _target = set.first;
    _choices = [...set]..shuffle();
    _item = ItemProgress();
    _dimmed.clear();
    _glowing = null;
    _line = 'Which letter makes this sound?';
    _shownAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSound());
  }

  void _playSound({double? rate}) {
    ref.read(speechProvider).speakPhoneme(_target.ttsFallback, rate: rate ?? _target.ttsRate);
  }

  Future<void> _choose(Grapheme g) async {
    if (_busy || _dimmed.contains(g.id)) return;
    _frustration.recordTap();
    final speech = ref.read(speechProvider);

    if (g.id == _target.id) {
      _busy = true;
      _item.solved = true;
      setState(() => _line = Praise.pick(Praise.success));
      await HapticFeedback.lightImpact();
      await speech.speakPhoneme(_target.ttsFallback);
      _frustration.recordOutcome(true);
      await _commitRound();
      return;
    }

    _item.misses++;
    _frustration.recordOutcome(false);
    setState(() => _line = _item.guideLine);

    switch (_item.support) {
      case SupportLevel.hint:
        // Narrow the field instead of scolding: the choice the child just made
        // stays on the table, so nothing they touched is snatched away.
        _playSound(rate: 0.22);
        setState(() {
          _dimmed.addAll(_choices
              .where((c) => c.id != _target.id && c.id != g.id)
              .map((c) => c.id));
        });
      case SupportLevel.demonstrate:
        setState(() => _glowing = _target.id);
        await speech.speak('This one.');
        await speech.speakPhoneme(_target.ttsFallback);
        setState(() => _line = 'Tap it with me.');
      case SupportLevel.none:
        break;
    }

    // Three misses ends the round kindly — the child is not left grinding.
    if (_item.misses >= 3) {
      await _commitRound();
      return;
    }
    if (_frustration.shouldOfferBreak) await _offerBreak();
  }

  Future<void> _commitRound() async {
    await ref.read(recordAttemptProvider)(
      childId: ref.read(activeChildProvider),
      sessionId: widget.sessionId,
      skillId: _target.id,
      skillType: 'grapheme',
      mode: GameMode.soundDetective,
      outcome: _item.outcome,
      hintsUsed: _item.misses,
      chosenValue: _item.solved ? _target.letters : null,
      responseMs: DateTime.now().difference(_shownAt).inMilliseconds,
      attemptKey: '${widget.activityKey}:round:$_round',
    );
    _outcomes.add(_item.outcome);

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    _busy = false;
    if (_round + 1 >= widget.rounds.length) {
      _finish();
    } else {
      setState(() {
        _round++;
        _loadRound();
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
    final reduceMotion = ref.watch(readingPrefsProvider).reduceMotion;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            children: [
              AnilGuide(size: 60, line: _line),
              const SizedBox(height: 8),
              // Rounds are shown as pebbles, not "3 of 5". No countdown, no
              // sense of a test running out.
              _RoundPebbles(total: widget.rounds.length, done: _round),
              const Spacer(),
              _MagnifyingGlass(reduceMotion: reduceMotion, onTap: _playSound),
              const SizedBox(height: 16),
              ReplayButton(onPressed: _playSound, label: 'Play the sound'),
              const Spacer(),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: _choices
                    .map((g) => _LetterCard(
                          grapheme: g,
                          dimmed: _dimmed.contains(g.id),
                          glowing: _glowing == g.id,
                          onTap: () => _choose(g),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MagnifyingGlass extends StatelessWidget {
  const _MagnifyingGlass({required this.onTap, required this.reduceMotion});

  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Play the sound again',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Tokens.sky.withValues(alpha: 0.20),
            border: Border.all(color: Tokens.sky, width: 6),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.search_rounded, size: 92, color: Tokens.ink),
        ),
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({
    required this.grapheme,
    required this.dimmed,
    required this.glowing,
    required this.onTap,
  });

  final Grapheme grapheme;
  final bool dimmed;
  final bool glowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'letter ${grapheme.letters}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: dimmed ? 0.30 : 1,
        child: GestureDetector(
          onTap: dimmed ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            width: 104,
            height: 128,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Tokens.radius),
              border: Border.all(
                color: glowing ? Tokens.marigold : Tokens.paperDeep,
                width: glowing ? 5 : 2,
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x11000000), blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              grapheme.letters,
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 72, height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress through the round set, shown as filled pebbles. Deliberately not
/// a number and never a countdown.
class _RoundPebbles extends StatelessWidget {
  const _RoundPebbles({required this.total, required this.done});

  final int total;
  final int done;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < done ? Tokens.leaf : Tokens.paperDeep,
              ),
            ),
          ),
      ],
    );
  }
}
