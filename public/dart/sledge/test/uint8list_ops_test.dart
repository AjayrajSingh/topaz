// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/src/uint8list_ops.dart';
import 'package:test/test.dart';

bool _listsAreEqualHelper(a, b) {
  final convertedA = new Uint8List.fromList(a);
  final convertedB = new Uint8List.fromList(b);
  return uint8ListsAreEqual(convertedA, convertedB);
}

void main() {
  setupLogger();
  test('Concatenation of Uint8Lists', () {
    final l1 = [1, 2], l2 = [3, 4, 5], l3 = [6];
    final uint8lConcat = concatListOfUint8Lists([
      new Uint8List.fromList(l1),
      new Uint8List.fromList(l2),
      new Uint8List.fromList(l3)
    ]);
    expect(uint8lConcat.toList(), equals([1, 2, 3, 4, 5, 6]));
  });

  test('Concatenation of Uint8Lists #2', () {
    final l1 = [1], l2 = [10], l3 = [3], l4 = [6];
    final uint8lConcat = concatListOfUint8Lists([
      new Uint8List.fromList(l1),
      new Uint8List.fromList(l2),
      new Uint8List.fromList(l3),
      new Uint8List.fromList(l4)
    ]);
    expect(uint8lConcat.toList(), equals([1, 10, 3, 6]));
  });

  test('Conversion from String to Uint8List', () {
    expect(getUint8ListFromString(''), equals([]));
    expect(getUint8ListFromString(' '), equals([32]));
    expect(getUint8ListFromString(' @'), equals([32, 64]));
    expect(getUint8ListFromString('🌸'), equals([0xf0, 0x9f, 0x8c, 0xb8]));
  });

  test('listsAreEqual', () {
    expect(uint8ListsAreEqual(null, null), equals(true));
    expect(uint8ListsAreEqual(new Uint8List.fromList([]), null), equals(false));
    expect(_listsAreEqualHelper(<int>[], <int>[]), equals(true));
    expect(_listsAreEqualHelper([1], <int>[]), equals(false));
    expect(_listsAreEqualHelper([1], [1]), equals(true));
    expect(_listsAreEqualHelper([1, 2], [1]), equals(false));
    expect(_listsAreEqualHelper([1, 2], [1, 2]), equals(true));
  });

  test('Ordered map with Uint8List keys of same length', () {
    final orderedMap = newUint8ListOrderedMap<int>();
    Random rand = new Random();
    for (int i = 0; i < 100; i++) {
      int value = rand.nextInt(0xffffffff);
      Uint8List key = new Uint8List(8)
        ..buffer.asByteData().setUint64(0, value, Endian.big);
      orderedMap[key] = value;
    }

    // Iterate over the KVs and verify that they are in order.
    int previousValue = -1;
    orderedMap.forEach((key, value) {
      expect(previousValue, lessThan(value));
      previousValue = value;
    });
  });

  test('Ordered map with Uint8List keys of different length', () {
    final orderedMap = newUint8ListOrderedMap<int>();
    orderedMap[getUint8ListFromString('')] = 0;
    orderedMap[getUint8ListFromString('A')] = 1;
    orderedMap[getUint8ListFromString('AA')] = 2;
    orderedMap[getUint8ListFromString('AAA')] = 3;

    // Iterate over the KVs and verify that they are in order.
    int previousValue = -1;
    orderedMap.forEach((key, value) {
      expect(previousValue, lessThan(value));
      previousValue = value;
    });
  });

  group('hasPrefix', () {
    test('both empty', () {
      expect(hasPrefix(new Uint8List(0), new Uint8List(0)), isTrue);
    });

    test('prefix empty', () {
      expect(hasPrefix(new Uint8List.fromList([1]), new Uint8List(0)), isTrue);
    });

    test('key empty', () {
      expect(hasPrefix(new Uint8List(0), new Uint8List.fromList([1])), isFalse);
    });

    test('prefix equals to key', () {
      expect(
          hasPrefix(
              new Uint8List.fromList([1, 3]), new Uint8List.fromList([1, 3])),
          isTrue);
    });

    test('prefix is a prefix of key', () {
      expect(
          hasPrefix(new Uint8List.fromList([1, 3, 2, 5]),
              new Uint8List.fromList([1, 3])),
          isTrue);
    });

    test('key is a prefix of prefix', () {
      expect(
          hasPrefix(new Uint8List.fromList([1, 3]),
              new Uint8List.fromList([1, 3, 2, 5])),
          isFalse);
    });

    test('same length, non equal', () {
      expect(
          hasPrefix(new Uint8List.fromList([1, 3, 4, 5]),
              new Uint8List.fromList([1, 3, 2, 5])),
          isFalse);
    });

    test('key shorter, not prefix', () {
      expect(
          hasPrefix(new Uint8List.fromList([1, 2]),
              new Uint8List.fromList([1, 3, 2, 5])),
          isFalse);
    });

    test('prefix shorter, not prefix', () {
      expect(
          hasPrefix(new Uint8List.fromList([1, 2, 4, 2]),
              new Uint8List.fromList([1, 3, 1])),
          isFalse);
    });
  });
}
