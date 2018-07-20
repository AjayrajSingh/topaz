// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../lib/src/deck.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/playing_card.dart'; // ignore: avoid_relative_lib_imports

class MockRandom extends Mock implements Random {}

void main() {
  test('unshuffledDeal', () {
    Deck underTest = new Deck();

    // Unshuffled deck should return in this order
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
        expect(
            underTest.dealCard(), equals(PlayingCard.fromAscii('$face$suit')));
      }
    }
  });

  test('shuffle resets deck', () {
    Deck underTest = new Deck();
    for (int i = 0; i < 10; i++) {
      underTest.dealCard();
    }
    expect(underTest.cardsInShoe, equals(42));

    underTest.shuffle();
    expect(underTest.cardsInShoe, equals(52));

    for (int i = 0; i < 52; i++) {
      underTest.dealCard();
    }
    expect(underTest.cardsInShoe, equals(0));
  });
}
