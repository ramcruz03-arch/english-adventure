import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/grapheme.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/content_repository.dart';

class AssetContentRepository implements ContentRepository {
  final _graphemes = <String, Grapheme>{};
  final _words = <String, Word>{};
  var _order = <String>[];

  @override
  Future<void> load() async {
    final g = jsonDecode(await rootBundle.loadString('assets/content/graphemes.json'))
        as Map<String, dynamic>;
    for (final j in (g['graphemes'] as List)) {
      final grapheme = Grapheme.fromJson(j as Map<String, dynamic>);
      _graphemes[grapheme.id] = grapheme;
    }
    _order = (g['curriculum_order'] as List).cast<String>();

    final w = jsonDecode(await rootBundle.loadString('assets/content/words.json'))
        as Map<String, dynamic>;
    for (final j in (w['words'] as List)) {
      final word = Word.fromJson(j as Map<String, dynamic>);
      _words[word.id] = word;
    }
  }

  @override
  List<Grapheme> get graphemes => _graphemes.values.toList();

  @override
  List<Word> get words => _words.values.toList();

  @override
  List<String> get curriculumOrder => _order;

  @override
  Grapheme? grapheme(String id) => _graphemes[id];

  @override
  Word? word(String id) => _words[id];
}
