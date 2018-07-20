// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Standard suits of playing cards. This is an enum behavior class with
/// extensions for understanding point value and conversion to/from ascii.
class Suit {
  final String _asciiValue;

  static const Suit clubs = const Suit._internal('C');
  static const Suit hearts = const Suit._internal('H');
  static const Suit spades = const Suit._internal('S');
  static const Suit diamonds = const Suit._internal('D');

  static final Map<String, Suit> fromAscii = <String, Suit>{
    'C': Suit.clubs,
    'H': Suit.hearts,
    'S': Suit.spades,
    'D': Suit.diamonds,
  };

  // Internal constructor
  const Suit._internal(this._asciiValue);

  @override
  String toString() => _asciiValue;

  static final List<Suit> values = <Suit>[
    clubs,
    hearts,
    spades,
    diamonds,
  ];
}
