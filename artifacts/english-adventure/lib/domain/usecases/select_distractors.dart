import 'dart:math';

import '../entities/grapheme.dart';

/// Choosing the wrong distractors is how phonics apps accidentally teach
/// b/d confusion. Below level 3 a confusable pair never appears in the same
/// choice set - the child is not ready to discriminate them yet.
List<Grapheme> selectDistractors({
  required Grapheme target,
  required List<Grapheme> taught,
  required int tier,
  required int childLevel,
  Random? rng,
}) {
  final r = rng ?? Random();
  var pool = taught.where((g) => g.id != target.id).toList();

  if (childLevel < 3) {
    pool = pool
        .where((g) =>
            !target.confusableWith.contains(g.id) && !g.confusableWith.contains(target.id))
        .toList();
  }

  final n = switch (tier) { 1 => 1, 2 => 2, _ => 3 };
  if (pool.length <= n) return pool;

  pool.shuffle(r);
  return pool.take(n).toList();
}
