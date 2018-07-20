// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'playing_card.dart';

class Hand {
  final List<PlayingCard> _cards;

  Hand() : _cards = <PlayingCard>[];

  /// Add a card to this player
  void add(PlayingCard card) {
    _cards.add(card);
  }

  void clear() {
    _cards.clear();
  }

  PlayingCard card(int index) => _cards[index];

  int get length => _cards.length;

  int get total {
    int sum = 0;
    int aceCount = 0;
    for (PlayingCard card in _cards) {
      sum += card.face.faceValue;
      if (card.face.faceValue == 11) {
        aceCount++;
      }
    }
    while (sum > 21 && aceCount > 0) {
      aceCount--;
      sum -= 10;
    }
    return sum;
  }

  @override
  String toString() {
    StringBuffer state = new StringBuffer()..write('Hand(');
    for (PlayingCard card in _cards) {
      state.write('${card.toString()},');
    }
    state.write('$total)');
    return state.toString();
  }
}
