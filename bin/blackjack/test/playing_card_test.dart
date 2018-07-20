// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/face.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/playing_card.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/suit.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('testface', () {
    expect(PlayingCard.fromAscii('9C').face, Face.nine);
    expect(PlayingCard.fromAscii('TD').face, Face.ten);
    expect(PlayingCard.fromAscii('JH').face, Face.jack);
    expect(PlayingCard.fromAscii('QS').face, Face.queen);
    expect(PlayingCard.fromAscii('KC').face, Face.king);
    expect(PlayingCard.fromAscii('AH').face, Face.ace);
  });

  test('testGetSuit', () {
    expect(PlayingCard.fromAscii('JH').suit, Suit.hearts);
    expect(PlayingCard.fromAscii('2C').suit, Suit.clubs);
  });

  test('testHashCode', () {
    expect(PlayingCard.fromAscii('KH').hashCode,
        equals(PlayingCard.fromAscii('KH').hashCode));
    expect(
        PlayingCard.fromAscii('KH').hashCode ==
            PlayingCard.fromAscii('QC').hashCode,
        isFalse);
  });

  test('testEquals', () {
    expect(PlayingCard.fromAscii('KH'), same(PlayingCard.fromAscii('KH')));
    expect(PlayingCard.fromAscii('KH') == PlayingCard.fromAscii('KH'), true);
    expect(PlayingCard.fromAscii('KH') == PlayingCard.fromAscii('QH'), false);
    expect(PlayingCard.fromAscii('KH') == PlayingCard.fromAscii('KC'), false);
    expect(PlayingCard.fromAscii('KH') == null, false);
  });

  test('testToFromString', () {
    for (String suit in <String>[
      'C',
      'H',
      'S',
      'D',
    ]) {
      for (String face in <String>[
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        'T',
        'J',
        'Q',
        'K',
        'A',
      ]) {
        String asciiValue = '$face$suit';
        expect(
            PlayingCard.fromAscii(asciiValue).toString(), equals(asciiValue));
      }
    }
  });
}
