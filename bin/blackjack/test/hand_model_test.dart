// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/hand_model.dart'; // ignore: avoid_relative_lib_imports
import '../lib/src/playing_card.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('addCards', () {
    HandModel underTest = new HandModel();

    expect(underTest.cardCount, equals(0));

    underTest.add(PlayingCard.fromAscii('KH'));
    expect(underTest.cardCount, equals(1));
    expect(underTest.total, equals(10));
    expect(underTest.card(0), equals(PlayingCard.fromAscii('KH')));

    underTest.add(PlayingCard.fromAscii('QD'));
    expect(underTest.cardCount, equals(2));
    expect(underTest.total, equals(20));
    expect(underTest.card(0), equals(PlayingCard.fromAscii('KH')));

    underTest.add(PlayingCard.fromAscii('9S'));
    expect(underTest.cardCount, equals(3));
    expect(underTest.total, equals(29));
    expect(underTest.card(0), equals(PlayingCard.fromAscii('KH')));

    underTest.clear();
    expect(underTest.cardCount, equals(0));
  });

  test('read cards', () {
    HandModel underTest = new HandModel()
      // This verifies notifyListeners() is called
      ..addListener(expectAsync0(
        () {},
        count: 1,
      ))
      ..add(PlayingCard.fromAscii('KH'))
      ..add(PlayingCard.fromAscii('QD'))
      ..add(PlayingCard.fromAscii('9S'));

    expect(underTest.cardCount, equals(3));
    expect(underTest.card(0), equals(PlayingCard.fromAscii('KH')));
    expect(underTest.card(1), equals(PlayingCard.fromAscii('QD')));
    expect(underTest.card(2), equals(PlayingCard.fromAscii('9S')));
  });

  test('aces', () {
    HandModel underTest = new HandModel()..add(PlayingCard.fromAscii('AD'));
    expect(underTest.total, equals(11));

    underTest.add(PlayingCard.fromAscii('AH'));
    expect(underTest.total, equals(12));

    underTest.add(PlayingCard.fromAscii('AS'));
    expect(underTest.total, equals(13));

    underTest.add(PlayingCard.fromAscii('AD'));
    expect(underTest.total, equals(14));

    underTest.add(PlayingCard.fromAscii('9S'));
    expect(underTest.total, equals(13));

    underTest.add(PlayingCard.fromAscii('8C'));
    expect(underTest.total, equals(21));
  });

  test('toString', () {
    HandModel underTest = new HandModel()
      ..add(PlayingCard.fromAscii('AD'))
      ..add(PlayingCard.fromAscii('AH'))
      ..add(PlayingCard.fromAscii('AS'))
      ..add(PlayingCard.fromAscii('AD'))
      ..add(PlayingCard.fromAscii('9S'))
      ..add(PlayingCard.fromAscii('6C'));

    expect(underTest.toString(), equals('HandModel(AD,AH,AS,AD,9S,6C,19)'));
  });

  test('bets', () {
    HandModel underTest = new HandModel();

    expect(underTest.bet, equals(0));

    underTest
      // This verifies notifyListeners() is called
      ..addListener(expectAsync0(
        () {},
        count: 1,
      ))
      ..bet = 50;
    expect(underTest.bet, equals(50));
  });

  test('splits', () {
    HandModel underTest = new HandModel()
      ..add(PlayingCard.fromAscii('AD'))
      ..add(PlayingCard.fromAscii('AH'));

    expect(underTest.canSplit, isTrue);
    // This verifies notifyListeners() is called
    underTest.addListener(expectAsync0(
      () {},
      count: 1,
    ));
    HandModel splitHand = underTest.split();
    expect(underTest.cardCount, equals(1));
    expect(underTest.card(0), equals(PlayingCard.fromAscii('AD')));
    expect(splitHand.cardCount, equals(1));
    expect(splitHand.card(0), equals(PlayingCard.fromAscii('AH')));
  });

  test('canSplit', () {
    HandModel underTest = new HandModel()..add(PlayingCard.fromAscii('AD'));

    expect(underTest.canSplit, isFalse);

    underTest.add(PlayingCard.fromAscii('AH'));
    expect(underTest.canSplit, isTrue);

    underTest.split();
    expect(underTest.canSplit, isFalse);

    underTest.add(PlayingCard.fromAscii('AC'));
    expect(underTest.canSplit, isTrue);
  });
}
