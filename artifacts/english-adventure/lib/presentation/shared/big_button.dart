import 'package:flutter/material.dart';

import '../../app/theme.dart';

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.colour = Tokens.leaf,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color colour;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 78, // well above the 64dp floor
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.play_arrow_rounded, size: 34),
        label: Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white, fontSize: 24)),
        style: FilledButton.styleFrom(
          backgroundColor: colour,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Tokens.radius)),
        ),
      ),
    );
  }
}

/// Listening is an action with its own affordance. Always present, always free.
class ReplayButton extends StatelessWidget {
  const ReplayButton({super.key, required this.onPressed, this.label = 'Hear it again'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          height: Tokens.minTap,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: Tokens.sky.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Tokens.sky, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.volume_up_rounded, size: 30, color: Tokens.ink),
              const SizedBox(width: 10),
              Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
