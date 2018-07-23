// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/player_model.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/playing_card.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('add cash', () {
    PlayerModel underTest = new PlayerModel();

    expect(underTest.cashAtTable, equals(0));

    underTest.addCash(500);
    expect(underTest.cashAtTable, equals(500));

    underTest.addCash(456);
    expect(underTest.cashAtTable, equals(956));

    expect(underTest.cashOut(), equals(956));
    expect(underTest.cashAtTable, equals(0));
  });

  test('canSplit', () {
    PlayerModel underTest = new PlayerModel();
    underTest.hand
      ..add(PlayingCard.fromAscii('AD'))
      ..add(PlayingCard.fromAscii('AH'));

    expect(underTest.canSplit, isTrue);

    underTest.split();
    expect(underTest.canSplit, isFalse);

    // Don't allow a second split
    underTest.hand.add(PlayingCard.fromAscii('AC'));
    expect(underTest.canSplit, isFalse);
  });

  test('split', () {
    PlayerModel underTest = new PlayerModel();
    underTest.hand
      ..add(PlayingCard.fromAscii('AD'))
      ..add(PlayingCard.fromAscii('AH'))
      ..bet = 200;
    underTest
      ..addCash(1000)
      ..commitBet();

    expect(underTest.canSplit, isTrue);
    expect(underTest.cashAtTable, equals(800));

    underTest.split();
    expect(underTest.cashAtTable, equals(600));
    expect(underTest.splitHand.bet, equals(200));
  });
}
