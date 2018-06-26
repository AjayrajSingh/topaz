// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:lib.ledger.dart/src/helpers.dart';
import 'package:test/test.dart';

void main() {
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
