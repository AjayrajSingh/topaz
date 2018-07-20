// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'face.dart';
import 'playing_card.dart';
import 'suit.dart';

class Deck {
  final List<PlayingCard> _cards;
  Random _randomizer;
  int _dealIndex;

  Deck()
      : _cards = <PlayingCard>[],
        _dealIndex = 0,
        _randomizer = new Random() {
    for (Suit suit in Suit.values) {
      for (Face face in Face.values) {
        _cards.add(PlayingCard.values[face][suit]);
      }
    }
  }

  void shuffle() {
    _cards.shuffle(_randomizer);
    _dealIndex = 0;
  }

  PlayingCard dealCard() {
    assert(_dealIndex < _cards.length);
    return _cards[_dealIndex++];
  }

  set randomForTesting(Random random) {
    _randomizer = random;
  }

  int get cardsInShoe => _cards.length - _dealIndex;
}
