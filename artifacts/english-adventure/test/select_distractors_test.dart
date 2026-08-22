import 'dart:math';

import 'package:english_adventure/domain/entities/grapheme.dart';
import 'package:english_adventure/domain/usecases/select_distractors.dart';
import 'package:flutter_test/flutter_test.dart';

Grapheme _g(String id, String letters, {List<String> confusable = const []}) => Grapheme(
      id: id,
      letters: letters,
      upper: letters.toUpperCase(),
      phoneme: '/$letters/',
      ttsFallback: letters,
      confusableWith: confusable,
    );

void main() {
  final b = _g('g:b', 'b', confusable: ['g:d']);
  final d = _g('g:d', 'd', confusable: ['g:b']);
  final s = _g('g:s', 's');
  final m = _g('g:m', 'm');
  final t = _g('g:t', 't');
  final all = [b, d, s, m, t];

  test('below level 3, b and d never share a table', () {
    for (var seed = 0; seed < 200; seed++) {
      final picked = selectDistractors(
        target: b,
        taught: all,
        tier: 3,
        childLevel: 2,
        rng: Random(seed),
      );
      expect(picked.map((g) => g.id), isNot(contains('g:d')),
          reason: 'a child who cannot yet tell b from d must not be asked to');
    }
  });

  test('at level 3 the confusable pair is allowed, because now it is the point', () {
    final seen = <String>{};
    for (var seed = 0; seed < 200; seed++) {
      seen.addAll(selectDistractors(
        target: b,
        taught: all,
        tier: 3,
        childLevel: 3,
        rng: Random(seed),
      ).map((g) => g.id));
    }
    expect(seen, contains('g:d'));
  });

  test('tier controls how many choices are on the table', () {
    expect(selectDistractors(target: s, taught: all, tier: 1, childLevel: 3).length, 1);
    expect(selectDistractors(target: s, taught: all, tier: 2, childLevel: 3).length, 2);
    expect(selectDistractors(target: s, taught: all, tier: 3, childLevel: 3).length, 3);
  });

  test('the target itself is never offered as its own distractor', () {
    final picked =
        selectDistractors(target: m, taught: all, tier: 3, childLevel: 3);
    expect(picked.map((g) => g.id), isNot(contains('g:m')));
  });

  test('a thin pool degrades gracefully instead of throwing', () {
    final picked =
        selectDistractors(target: t, taught: [t, s], tier: 3, childLevel: 3);
    expect(picked.length, 1);
  });
}
