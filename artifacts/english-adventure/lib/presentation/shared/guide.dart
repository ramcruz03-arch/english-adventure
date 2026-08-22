import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Anil, a three-striped palm squirrel - the child's guide.
///
/// This small vector mark is intentionally drawn in Flutter so it is crisp on
/// every device and never depends on a platform emoji font. It can later be
/// replaced by illustrated poses without changing any screen API.
class AnilGuide extends StatelessWidget {
  const AnilGuide({super.key, this.size = 72, this.line});

  final double size;
  final String? line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(color: Tokens.leafLight, shape: BoxShape.circle),
          alignment: Alignment.center,
           child: CustomPaint(
             size: Size.square(size * 0.72),
             painter: _AnilPainter(),
           ),
        ),
        if (line != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Tokens.radius),
                border: Border.all(color: Tokens.paperDeep, width: 2),
              ),
              child: Text(line!, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ],
    );
  }
}

class _AnilPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 72;
    canvas.scale(scale);

    final fur = Paint()..color = const Color(0xFF9A6548);
    final belly = Paint()..color = const Color(0xFFF4D3A8);
    final ink = Paint()
      ..color = Tokens.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final stripe = Paint()
      ..color = const Color(0xFFF8E8C6)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Curled tail, body, and ears.
    final tail = Path()
      ..moveTo(22, 46)
      ..cubicTo(2, 54, 8, 18, 30, 25)
      ..cubicTo(47, 30, 41, 48, 28, 43);
    canvas.drawPath(tail, fur);
    canvas.drawOval(const Rect.fromLTWH(24, 25, 32, 38), fur);
    canvas.drawCircle(const Offset(48, 24), 15, fur);
    canvas.drawPath(
      Path()
        ..moveTo(38, 14)
        ..lineTo(39, 3)
        ..lineTo(47, 12)
        ..close(),
      fur,
    );
    canvas.drawPath(
      Path()
        ..moveTo(51, 12)
        ..lineTo(59, 3)
        ..lineTo(59, 17)
        ..close(),
      fur,
    );
    canvas.drawOval(const Rect.fromLTWH(33, 33, 15, 24), belly);

    // Three pale stripes are Anil's recognizable feature.
    canvas.drawLine(const Offset(29, 32), const Offset(39, 38), stripe);
    canvas.drawLine(const Offset(28, 38), const Offset(38, 44), stripe);
    canvas.drawLine(const Offset(28, 44), const Offset(37, 50), stripe);

    ink.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(42, 22), 2.5, ink);
    canvas.drawCircle(const Offset(54, 22), 2.5, ink);
    ink.style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(46, 28), const Offset(50, 28), ink);
    canvas.drawLine(const Offset(48, 29), const Offset(48, 32), ink);
    canvas.drawLine(const Offset(48, 32), const Offset(44, 34), ink);
    canvas.drawLine(const Offset(48, 32), const Offset(52, 34), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
