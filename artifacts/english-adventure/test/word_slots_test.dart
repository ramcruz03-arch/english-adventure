import 'package:english_adventure/domain/usecases/word_slots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('slots fill left to right, because that is the order blending needs', () {
    final b = SlotBoard(['c', 'a', 't']);
    expect(b.place('a'), isNull, reason: 'a is right, but not yet');
    expect(b.place('c'), 0);
    expect(b.place('a'), 1);
    expect(b.place('t'), 2);
    expect(b.isComplete, isTrue);
  });

  test('a wrong letter changes nothing at all', () {
    final b = SlotBoard(['s', 'i', 't']);
    b.place('t');
    expect(b.placed, [null, null, null]);
    expect(b.remaining(), ['s', 'i', 't']);
    expect(b.activeSlot, 0);
  });

  test('duplicate letters leave the tray one at a time', () {
    final b = SlotBoard(['d', 'a', 'd']);
    b.place('d');
    expect(b.remaining(), ['a', 'd'], reason: 'the second d must still be there');
    b.place('a');
    b.place('d');
    expect(b.isComplete, isTrue);
    expect(b.remaining(), isEmpty);
  });

  test('after two misses the app finishes the step instead of the child grinding', () {
    final b = SlotBoard(['m', 'a', 'p']);
    expect(b.placeCorrectOne(), 0);
    expect(b.placed.first, 'm');
    expect(b.activeSlot, 1);
  });

  test('a completed board has no active slot and accepts nothing more', () {
    final b = SlotBoard(['a', 't']);
    b.place('a');
    b.place('t');
    expect(b.activeSlot, isNull);
    expect(b.accepts('a'), isFalse);
    expect(b.placeCorrectOne(), isNull);
  });

  test('reset returns every letter to the tray', () {
    final b = SlotBoard(['p', 'i', 'n']);
    b.place('p');
    b.reset();
    expect(b.placed, [null, null, null]);
    expect(b.remaining(), ['p', 'i', 'n']);
  });
}
