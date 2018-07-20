// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Face card value for a playing card. This is an enum behavior class with
/// extensions for understanding point value and conversion to/from ascii.
class Face {
  static const Face two = const Face._internal(2, '2');
  static const Face three = const Face._internal(3, '3');
  static const Face four = const Face._internal(4, '4');
  static const Face five = const Face._internal(5, '5');
  static const Face six = const Face._internal(6, '6');
  static const Face seven = const Face._internal(7, '7');
  static const Face eight = const Face._internal(8, '8');
  static const Face nine = const Face._internal(9, '9');
  static const Face ten = const Face._internal(10, 'T');
  static const Face jack = const Face._internal(10, 'J');
  static const Face queen = const Face._internal(10, 'Q');
  static const Face king = const Face._internal(10, 'K');
  static const Face ace = const Face._internal(11, 'A');

  // Internal constructor
  const Face._internal(this.faceValue, this.asciiValue);

  @override
  String toString() => asciiValue;

  // ignore_for_file: hash_and_equals
  @override
  int get hashCode => (617 + faceValue.hashCode) * 37 + asciiValue.hashCode;

  static final List<Face> values = [
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    ten,
    jack,
    queen,
    king,
    ace,
  ];
  static final List<Face> descendingFaces = [ace, king, queen, jack, ten, nine];

  /// Get the Face value represented by the specified string
  static final Map<String, Face> fromAscii = <String, Face>{
    two.asciiValue: two,
    three.asciiValue: three,
    four.asciiValue: four,
    five.asciiValue: five,
    six.asciiValue: six,
    seven.asciiValue: seven,
    eight.asciiValue: eight,
    nine.asciiValue: nine,
    ten.asciiValue: ten,
    jack.asciiValue: jack,
    queen.asciiValue: queen,
    king.asciiValue: king,
    ace.asciiValue: ace,
  };

  final int faceValue;
  final String asciiValue;
}
