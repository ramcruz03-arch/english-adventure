class StrokePath {
  const StrokePath({required this.order, required this.svg, this.arrows = const []});

  final int order;
  final String svg;
  final List<List<double>> arrows;

  factory StrokePath.fromJson(Map<String, dynamic> j) => StrokePath(
        order: j['order'] as int,
        svg: j['svg'] as String,
        arrows: ((j['arrows'] ?? []) as List)
            .map((a) => (a as List).map((n) => (n as num).toDouble()).toList())
            .toList(),
      );
}

/// One letter-to-sound correspondence. The unit the whole curriculum is built on.
class Grapheme {
  const Grapheme({
    required this.id,
    required this.letters,
    required this.upper,
    required this.phoneme,
    required this.ttsFallback,
    this.ttsRate = 0.35,
    this.soundAudio,
    this.exampleWordIds = const [],
    this.confusableWith = const [],
    this.strokes = const [],
  });

  final String id;          // 'g:s'
  final String letters;     // 's'
  final String upper;       // 'S'
  final String phoneme;     // '/s/'
  final String ttsFallback; // 'sss'  <- what TTS must say, never the letter name
  final double ttsRate;
  final String? soundAudio; // recorded audio path, when it exists
  final List<String> exampleWordIds;
  final List<String> confusableWith; // 'g:b' <-> 'g:d'
  final List<StrokePath> strokes;

  factory Grapheme.fromJson(Map<String, dynamic> j) => Grapheme(
        id: j['id'] as String,
        letters: j['letters'] as String,
        upper: j['upper'] as String,
        phoneme: j['phoneme'] as String,
        ttsFallback: (j['tts_fallback'] ?? {})['text'] as String? ?? j['letters'] as String,
        ttsRate: (((j['tts_fallback'] ?? {})['rate']) as num?)?.toDouble() ?? 0.35,
        soundAudio: j['sound_audio'] as String?,
        exampleWordIds: ((j['example_words'] ?? []) as List).cast<String>(),
        confusableWith: ((j['confusable_with'] ?? []) as List).cast<String>(),
        strokes: ((j['stroke_paths'] ?? []) as List)
            .map((s) => StrokePath.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
