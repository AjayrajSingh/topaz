// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../lib/src/face.dart'; // ignore: avoid_relative_lib_imports

void main() {
  test('testAscii', () {
    expect(Face.two.toString(), equals('2'));
    expect(Face.three.toString(), equals('3'));
    expect(Face.four.toString(), equals('4'));
    expect(Face.five.toString(), equals('5'));
    expect(Face.six.toString(), equals('6'));
    expect(Face.seven.toString(), equals('7'));
    expect(Face.eight.toString(), equals('8'));
    expect(Face.nine.toString(), equals('9'));
    expect(Face.ten.toString(), equals('T'));
    expect(Face.jack.toString(), equals('J'));
    expect(Face.queen.toString(), equals('Q'));
    expect(Face.king.toString(), equals('K'));
    expect(Face.ace.toString(), equals('A'));

    expect(Face.fromAscii['2'], same(Face.two));
    expect(Face.fromAscii['3'], same(Face.three));
    expect(Face.fromAscii['4'], same(Face.four));
    expect(Face.fromAscii['5'], same(Face.five));
    expect(Face.fromAscii['6'], same(Face.six));
    expect(Face.fromAscii['7'], same(Face.seven));
    expect(Face.fromAscii['8'], same(Face.eight));
    expect(Face.fromAscii['9'], same(Face.nine));
    expect(Face.fromAscii['T'], same(Face.ten));
    expect(Face.fromAscii['J'], same(Face.jack));
    expect(Face.fromAscii['Q'], same(Face.queen));
    expect(Face.fromAscii['K'], same(Face.king));
    expect(Face.fromAscii['A'], same(Face.ace));
  });

  test('testHashCode', () {
    expect(Face.queen.hashCode, Face.queen.hashCode);
    expect(Face.queen.hashCode == Face.king.hashCode, isFalse);
  });

  test('point value', () {
    expect(Face.two.faceValue, equals(2));
    expect(Face.three.faceValue, equals(3));
    expect(Face.four.faceValue, equals(4));
    expect(Face.five.faceValue, equals(5));
    expect(Face.six.faceValue, equals(6));
    expect(Face.seven.faceValue, equals(7));
    expect(Face.eight.faceValue, equals(8));
    expect(Face.nine.faceValue, equals(9));
    expect(Face.ten.faceValue, equals(10));
    expect(Face.jack.faceValue, equals(10));
    expect(Face.queen.faceValue, equals(10));
    expect(Face.king.faceValue, equals(10));
    expect(Face.ace.faceValue, equals(11));
  });
}
