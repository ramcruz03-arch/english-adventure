import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The signature element: one letter, big enough to be the whole world,
/// resting on a garden stone. Tapping it always replays the sound - the child
/// can never get stuck for want of hearing it again.
class SoundStone extends StatefulWidget {
  const SoundStone({
    super.key,
    required this.letter,
    required this.onTap,
    this.reduceMotion = false,
  });

  final String letter;
  final VoidCallback onTap;
  final bool reduceMotion;

  @override
  State<SoundStone> createState() => _SoundStoneState();
}

class _SoundStoneState extends State<SoundStone> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _tap() {
    if (!widget.reduceMotion) _c.reverse().then((_) => _c.forward());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Letter ${widget.letter}. Tap to hear its sound.',
      child: GestureDetector(
        onTap: _tap,
        child: ScaleTransition(
          scale: _c,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(48),
              border: Border.all(color: Tokens.leafLight, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 8)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              widget.letter,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(height: 1.0),
            ),
          ),
        ),
      ),
    );
  }
}
