import '../entities/grapheme.dart';
import '../entities/word.dart';

/// Content is data, never code. Swap the asset loader for a downloaded
/// content pack without touching a single game screen.
abstract class ContentRepository {
  Future<void> load();

  List<Grapheme> get graphemes;
  List<Word> get words;

  /// Curriculum order: s a t p / i n m d / g o c k / ...
  /// High-utility letters first so real words are readable from lesson 3.
  List<String> get curriculumOrder;

  Grapheme? grapheme(String id);
  Word? word(String id);
}
