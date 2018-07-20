// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/suit.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('testAscii', () {
    expect(Suit.clubs.toString(), 'C');
    expect(Suit.spades.toString(), 'S');
    expect(Suit.diamonds.toString(), 'D');
    expect(Suit.hearts.toString(), 'H');

    expect(Suit.fromAscii['C'], Suit.clubs);
    expect(Suit.fromAscii['S'], Suit.spades);
    expect(Suit.fromAscii['D'], Suit.diamonds);
    expect(Suit.fromAscii['H'], Suit.hearts);
  });

  test('testHashCode', () {
    expect(Suit.clubs.hashCode, equals(Suit.clubs.hashCode));
    expect(Suit.hearts.hashCode == Suit.clubs.hashCode, isFalse);
  });
}
