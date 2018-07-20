// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'face.dart';
import 'suit.dart';

/// This is called PlayingCard as there is a conflict with Material and the
/// class card therein.
class PlayingCard {
  /// Face value for this card
  final Face face;

  /// Natural suit of this card
  final Suit suit;

  const PlayingCard._internal(this.face, this.suit);

  /// Access a card given the two character string for that card
  static PlayingCard fromAscii(String str) =>
      values[Face.fromAscii[str.substring(0, 1)]]
          [Suit.fromAscii[str.substring(1)]];

  @override
  bool operator ==(Object o) =>
      o is PlayingCard && o.face == face && o.suit == suit;

  @override
  int get hashCode => (617 + face.hashCode) * 37 + suit.hashCode;

  @override
  String toString() => '${face.toString()}${suit.toString()}';

  static final Map<Face, Map<Suit, PlayingCard>> values = {
    Face.two: {
      Suit.clubs: const PlayingCard._internal(Face.two, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.two, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.two, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.two, Suit.diamonds),
    },
    Face.three: {
      Suit.clubs: const PlayingCard._internal(Face.three, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.three, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.three, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.three, Suit.diamonds),
    },
    Face.four: {
      Suit.clubs: const PlayingCard._internal(Face.four, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.four, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.four, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.four, Suit.diamonds),
    },
    Face.five: {
      Suit.clubs: const PlayingCard._internal(Face.five, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.five, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.five, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.five, Suit.diamonds),
    },
    Face.six: {
      Suit.clubs: const PlayingCard._internal(Face.six, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.six, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.six, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.six, Suit.diamonds),
    },
    Face.seven: {
      Suit.clubs: const PlayingCard._internal(Face.seven, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.seven, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.seven, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.seven, Suit.diamonds),
    },
    Face.eight: {
      Suit.clubs: const PlayingCard._internal(Face.eight, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.eight, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.eight, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.eight, Suit.diamonds),
    },
    Face.nine: {
      Suit.clubs: const PlayingCard._internal(Face.nine, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.nine, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.nine, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.nine, Suit.diamonds),
    },
    Face.ten: {
      Suit.clubs: const PlayingCard._internal(Face.ten, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.ten, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.ten, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.ten, Suit.diamonds),
    },
    Face.jack: {
      Suit.clubs: const PlayingCard._internal(Face.jack, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.jack, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.jack, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.jack, Suit.diamonds),
    },
    Face.queen: {
      Suit.clubs: const PlayingCard._internal(Face.queen, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.queen, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.queen, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.queen, Suit.diamonds),
    },
    Face.king: {
      Suit.clubs: const PlayingCard._internal(Face.king, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.king, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.king, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.king, Suit.diamonds),
    },
    Face.ace: {
      Suit.clubs: const PlayingCard._internal(Face.ace, Suit.clubs),
      Suit.spades: const PlayingCard._internal(Face.ace, Suit.spades),
      Suit.hearts: const PlayingCard._internal(Face.ace, Suit.hearts),
      Suit.diamonds: const PlayingCard._internal(Face.ace, Suit.diamonds),
    },
  };
}
