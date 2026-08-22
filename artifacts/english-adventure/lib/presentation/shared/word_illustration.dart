import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../domain/entities/word.dart';

/// A deterministic, no-network illustration for the content pack.
///
/// Content illustrations are local bundled PNG assets, so the child never sees a
/// platform-dependent emoji or a network-dependent image. The pictogram map
/// remains a safe fallback for future or partially downloaded content packs.
class WordIllustration extends StatelessWidget {
  const WordIllustration({super.key, required this.word, this.size = 64});

  final Word word;
  final double size;

  static const _icons = <String, IconData>{
    'sun': Icons.wb_sunny_rounded,
    'sock': Icons.local_laundry_service_rounded,
    'sit': Icons.airline_seat_recline_normal_rounded,
    'tap': Icons.touch_app_rounded,
    'tin': Icons.inventory_2_rounded,
    'top': Icons.vertical_align_top_rounded,
    'pan': Icons.outdoor_grill_rounded,
    'pin': Icons.push_pin_rounded,
    'pot': Icons.soup_kitchen_rounded,
    'map': Icons.map_rounded,
    'man': Icons.person_rounded,
    'mat': Icons.crop_square_rounded,
    'nap': Icons.bed_rounded,
    'net': Icons.grid_on_rounded,
    'nut': Icons.park_rounded,
    'dog': Icons.pets_rounded,
    'dad': Icons.person_rounded,
    'ant': Icons.bug_report_rounded,
    'apple': Icons.local_grocery_store_rounded,
    'the': Icons.auto_stories_rounded,
    'a': Icons.menu_book_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (word.image != null && word.image!.isNotEmpty) {
      return Image.asset(
        word.image!,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => _icon(),
      );
    }
    return _icon();
  }

  Widget _icon() => ExcludeSemantics(
        child: Icon(
          _icons[word.text.toLowerCase()] ?? Icons.image_rounded,
          size: size,
          color: Tokens.leaf,
        ),
      );
}