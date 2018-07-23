// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.widgets/model.dart';

import 'playing_card.dart';

class HandModel extends Model {
  /// Since blackjack pays 1.5 x bet, all bets need to have a multiple so a
  /// half chip can be awarded in the case of blackjack. All bets must be a
  /// multiple of this value.
  static const int minChipValue = 10;

  final List<PlayingCard> _cards;
  int _bet;

  HandModel()
      : _bet = 0,
        _cards = <PlayingCard>[];

  /// Set the bet for this hand.
  set bet(int bet) {
    assert(bet >= 0 && bet % minChipValue == 0);
    _bet = bet;
    notifyListeners();
  }

  /// The bet for this hand
  int get bet => _bet;

  /// Add a card to this hand
  void add(PlayingCard card) {
    _cards.add(card);
    notifyListeners();
  }

  void clear() {
    _cards.clear();
    notifyListeners();
  }

  PlayingCard card(int index) => _cards[index];

  /// How many cards has this hand been dealt
  int get cardCount => _cards.length;

  /// The maximum value for this hand accounting for Aces being either 11 or 1.
  /// If valuing an ace as 11 would bust this hand, the Ace is valued as 1.
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

  /// A hand can be split if it contains two cards with the safe face
  bool get canSplit => _cards.length == 2 && _cards[0].face == _cards[1].face;

  /// Remove one of the cards from this instance to split to another hand.
  /// Create a new HandModel that contains the removed card.
  HandModel split() {
    assert(canSplit);
    HandModel result = new HandModel()..add(_cards.removeAt(1));
    notifyListeners();
    return result;
  }

  @override
  String toString() {
    StringBuffer state = new StringBuffer()..write('HandModel(');
    for (PlayingCard card in _cards) {
      state.write('${card.toString()},');
    }
    state.write('$total)');
    return state.toString();
  }
}
