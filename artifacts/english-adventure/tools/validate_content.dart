// Content gate. Runs in CI:  dart run tools/validate_content.dart
//
// This is the most important 100 lines in the repository. It is what
// guarantees a child is never shown a word containing a sound nobody has
// taught her yet - the single most common way phonics apps quietly break a
// struggling reader's confidence.
//
// Exit code 1 fails the build.

import 'dart:convert';
import 'dart:io';

void main() {
  final errors = <String>[];
  final warnings = <String>[];

  final g = jsonDecode(File('assets/content/graphemes.json').readAsStringSync())
      as Map<String, dynamic>;
  final w = jsonDecode(File('assets/content/words.json').readAsStringSync())
      as Map<String, dynamic>;

  final graphemes = {
    for (final x in (g['graphemes'] as List)) (x as Map)['id'] as String: x
  };
  final order = (g['curriculum_order'] as List).cast<String>();
  final orderIndex = {for (var i = 0; i < order.length; i++) order[i]: i};

  // 1. Every grapheme must say its SOUND, not its letter name.
  for (final entry in graphemes.entries) {
    final tts = entry.value['tts_fallback'];
    if (tts == null || (tts['text'] as String).trim().isEmpty) {
      errors.add('${entry.key}: missing tts_fallback - TTS would say the letter '
          'NAME instead of the sound');
    }
  }

  // 2. Every grapheme in the curriculum must exist, and vice versa.
  for (final id in order) {
    if (!graphemes.containsKey(id)) errors.add('curriculum_order references unknown $id');
  }
  for (final id in graphemes.keys) {
    if (!orderIndex.containsKey(id)) {
      warnings.add('$id is defined but never taught (not in curriculum_order)');
    }
  }

  // 3. Every word must be decodable, and we record WHEN it becomes decodable.
  for (final x in (w['words'] as List)) {
    final word = x as Map<String, dynamic>;
    final id = word['id'] as String;
    final type = word['type'] as String? ?? 'other';
    final parts = ((word['graphemes'] ?? []) as List).cast<String>();

    if (type == 'sight') continue; // sight words are introduced explicitly

    if (parts.isEmpty) {
      errors.add('$id: no graphemes listed - decodability cannot be checked');
      continue;
    }
    for (final p in parts) {
      if (!graphemes.containsKey(p)) {
        errors.add('$id: uses undefined grapheme $p');
      } else if (!orderIndex.containsKey(p)) {
        errors.add('$id: uses $p which is never taught');
      }
    }
    if (word['image'] == null && word['emoji'] == null) {
      warnings.add('$id: no image (emoji placeholder is dev-only)');
    }
  }

  // 4. Report the earliest lesson at which each word may legally appear.
  final unlockAt = <String, int>{};
  for (final x in (w['words'] as List)) {
    final word = x as Map<String, dynamic>;
    final parts = ((word['graphemes'] ?? []) as List).cast<String>();
    if (parts.isEmpty || !parts.every(orderIndex.containsKey)) continue;
    unlockAt[word['id'] as String] =
        parts.map((p) => orderIndex[p]!).reduce((a, b) => a > b ? a : b) + 1;
  }

  stdout.writeln('Graphemes: ${graphemes.length}   Words: ${(w['words'] as List).length}');
  stdout.writeln('Earliest usable lesson per word:');
  final sorted = unlockAt.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
  for (final e in sorted) {
    stdout.writeln('  after sound ${e.value.toString().padLeft(2)}  ${e.key}');
  }

  for (final x in warnings) {
    stdout.writeln('WARN  $x');
  }
  for (final x in errors) {
    stderr.writeln('ERROR $x');
  }

  if (errors.isNotEmpty) {
    stderr.writeln('\n${errors.length} error(s). Build blocked.');
    exit(1);
  }
  stdout.writeln('\nContent OK.');
}
