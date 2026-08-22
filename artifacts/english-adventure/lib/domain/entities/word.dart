enum WordType { cvc, sight, other }

class Word {
  const Word({
    required this.id,
    required this.text,
    required this.type,
    this.graphemeIds = const [],
    this.phonemes = const [],
    this.image,
    this.emoji,
    this.audio,
  });

  final String id;
  final String text;
  final WordType type;
  final List<String> graphemeIds;
  final List<String> phonemes;
  final String? image;
  /// Legacy content field. Child-facing screens must use WordIllustration or
  /// the real image asset instead of rendering this platform-dependent glyph.
  final String? emoji;
  final String? audio;

  /// The rule that protects the child: a word may only be shown when every
  /// grapheme in it has already been taught. Sight words are the one exception
  /// and are introduced explicitly, never as decoding practice.
  bool isDecodableWith(Set<String> taught) =>
      type == WordType.sight || graphemeIds.every(taught.contains);

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        text: j['text'] as String,
        type: switch (j['type'] as String?) {
          'cvc' => WordType.cvc,
          'sight' => WordType.sight,
          _ => WordType.other,
        },
        graphemeIds: ((j['graphemes'] ?? []) as List).cast<String>(),
        phonemes: ((j['phonemes'] ?? []) as List).cast<String>(),
        image: j['image'] as String?,
        emoji: j['emoji'] as String?,
        audio: j['audio'] as String?,
      );
}
