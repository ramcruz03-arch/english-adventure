import 'dart:math';

/// The only words the app is allowed to say about performance.
///
/// There is deliberately no "incorrect" list. A miss produces a *teaching*
/// line, never a verdict. Nothing here contains wrong, no, failed, slow,
/// or any comparison to another child.
class Praise {
  static final _r = Random();

  static const success = [
    'Great listening!',
    'You found the sound!',
    'Wonderful effort!',
    'That is it!',
    'Your ears are sharp today.',
  ];

  static const firstHint = [
    'Almost there - listen carefully.',
    'Let us hear it once more.',
    'Close! Listen to the first sound.',
  ];

  static const demonstrate = [
    'Let us try it together.',
    'I will show you, then you try.',
    'Watch me first.',
  ];

  static const sessionEnd = [
    'You worked hard today. Well done!',
    'Look how much you did!',
    'Anil is proud of you.',
  ];

  static const offerBreak = [
    'Shall we take a little break?',
    'That was tricky. Want to rest a moment?',
  ];

  static String pick(List<String> from) => from[_r.nextInt(from.length)];
}
