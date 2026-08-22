import 'dart:math' as math;

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
import '../../shared/sound_stone.dart';

/// Trace & Write: a forgiving, offline-first tracing activity.
///
/// The guide is always visible and the child can try again without losing a
/// star. A sample is saved for the parent view, while the score only decides
/// how much support to offer on this attempt.
class TraceWriteScreen extends ConsumerStatefulWidget {
  const TraceWriteScreen({
    super.key,
    required this.activity,
    required this.sessionId,
    required this.activityKey,
    required this.target,
    required this.onDone,
  });

  final Activity activity;
  final String sessionId;
  final String activityKey;
  final Grapheme target;
  final void Function(double averageOutcome) onDone;

  @override
  ConsumerState<TraceWriteScreen> createState() => _TraceWriteScreenState();
}

class _TraceWriteScreenState extends ConsumerState<TraceWriteScreen> {
  final _points = <Offset>[];
  String _line = 'Trace the letter with your finger';
  bool _complete = false;
  bool _finishing = false;
  double? _lastScore;

  void _speak() => ref.read(speechProvider).speakPhoneme(
        widget.target.ttsFallback,
        rate: widget.target.ttsRate,
      );

  void _addPoint(Offset point) {
    if (_complete) return;
    setState(() => _points.add(point));
  }

  Future<void> _finishStroke() async {
    if (_complete || _finishing) return;
    if (_points.length < 8) {
      setState(() => _line = 'Take your time and make a few more strokes');
      return;
    }

    final score = _score(_points);
    _finishing = true;
    _lastScore = score;
    await HapticFeedback.lightImpact();
    if (!mounted) return;

    if (score < 0.55) {
      setState(() {
        _line = 'Nice try. Trace along the big letter once more';
        _finishing = false;
      });
      return;
    }

    setState(() {
      _complete = true;
      _line = Praise.pick(Praise.success);
    });
    await ref.read(progressRepositoryProvider).saveTracingSample(
          childId: ref.read(activeChildProvider),
          glyphId: widget.target.id,
          coverage: score,
          meanDeviation: 1 - score,
          strokeOrderOk: true,
          sampleKey: '${widget.sessionId}:${widget.activityKey}:finish',
        );
    await ref.read(recordAttemptProvider)(
      childId: ref.read(activeChildProvider),
      sessionId: widget.sessionId,
      skillId: widget.target.id,
      skillType: 'grapheme',
      mode: GameMode.traceWrite,
      outcome: score,
      attemptKey: '${widget.activityKey}:finish',
    );
  }

  // A deliberately forgiving MVP scorer: it rewards sustained movement across
  // the guide area rather than penalising a child's exact handwriting style.
  double _score(List<Offset> points) {
    final cells = <String>{};
    for (final p in points) {
      cells.add('${(p.dx / 34).floor()}:${(p.dy / 34).floor()}');
    }
    final spread = math.min(1.0, cells.length / 12);
    final movement = math.min(1.0, points.length / 70);
    return (spread * 0.65 + movement * 0.35).clamp(0.0, 1.0).toDouble();
  }

  void _tryAgain() => setState(() {
        _points.clear();
        _lastScore = null;
        _line = 'Trace the letter with your finger';
      });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = ref.watch(readingPrefsProvider).reduceMotion;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.gutter),
          child: Column(
            children: [
              AnilGuide(size: 64, line: _line),
              const SizedBox(height: 12),
              SoundStone(
                letter: widget.target.letters,
                reduceMotion: reduceMotion,
                onTap: _speak,
              ),
              const SizedBox(height: 8),
              ReplayButton(onPressed: _speak),
              const SizedBox(height: 12),
              Expanded(
                child: Semantics(
                  label: 'Tracing board for ${widget.target.upper}',
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Tokens.paperDeep,
                      borderRadius: BorderRadius.circular(Tokens.radius),
                    ),
                    child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => _addPoint(d.localPosition),
                        onPanUpdate: (d) => _addPoint(d.localPosition),
                        onPanEnd: (_) => _finishStroke(),
                        child: CustomPaint(
                          painter: _TracingPainter(
                            letter: widget.target.upper,
                            points: _points,
                            complete: _complete,
                          ),
                          size: Size.infinite,
                        ),
                    ),
                  ),
                ),
              ),
              if (_lastScore != null && !_complete)
                TextButton.icon(
                  onPressed: _tryAgain,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try the letter again'),
                ),
              const SizedBox(height: 8),
              BigButton(
                label: _complete ? 'Continue' : 'I’m ready',
                icon: _complete ? Icons.check_rounded : Icons.arrow_forward_rounded,
                colour: Tokens.marigold,
                onPressed: _complete
                    ? () => widget.onDone(_lastScore ?? 1.0)
                    : _finishStroke,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TracingPainter extends CustomPainter {
  const _TracingPainter({
    required this.letter,
    required this.points,
    required this.complete,
  });

  final String letter;
  final List<Offset> points;
  final bool complete;

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Paint()
      ..color = complete ? Tokens.leafLight : Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    final text = TextPainter(
      text: TextSpan(
        text: letter,
        style: TextStyle(
          fontFamily: Tokens.learningFace,
          fontSize: math.min(size.width, size.height) * 0.7,
          fontWeight: FontWeight.w700,
          color: guide.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(
      canvas,
      Offset((size.width - text.width) / 2, (size.height - text.height) / 2),
    );

    if (points.isEmpty) return;
    final stroke = Paint()
      ..color = complete ? Tokens.leaf : Tokens.marigold
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) =>
      oldDelegate.points.length != points.length ||
      oldDelegate.complete != complete ||
      oldDelegate.letter != letter;
}