// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:sledge/src/document/values/compressor.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  group('Correct compression', () {
    test('KeyValue', () {
      final c = new Compressor(), c1 = new Compressor();
      final kv = new KeyValue(
          new Uint8List.fromList([1, 2, 3]), new Uint8List.fromList([4, 5]));
      final kv2 = c.uncompressKeyInEntry(c1.compressKeyInEntry(kv));
      expect(kv2, new KeyValueMatcher(kv));
    });

    test('Key', () {
      final c = new Compressor();
      final key = new Uint8List.fromList([3, 8, 2]);
      final keyUc = c.uncompressKey(c.compressKey(key));
      expect(keyUc, new Uint8ListMatcher(key));

      final keyOth = new Uint8List.fromList([3]);
      final keyOthUc = c.uncompressKey(c.compressKey(keyOth));
      expect(keyOthUc, new Uint8ListMatcher(keyOth));
    });
  });

  group('Exceptions', () {
    test('Uncompress new key', () {
      final c = new Compressor(), c1 = new Compressor();
      expect(
          () => c.uncompressKey(c1.compressKey(new Uint8List.fromList([1, 2]))),
          throwsFormatException);
    });

    test('Uncompress short key', () {
      final c = new Compressor();
      expect(() => c.uncompressKey(new Uint8List.fromList([1, 2])),
          throwsFormatException);
    });

    test('Uncompress key value with wrong key length', () {
      final c = new Compressor();
      final kv = new KeyValue(
          new Uint8List.fromList([1, 2, 3]), new Uint8List.fromList([4, 5]));
      final kvC = c.compressKeyInEntry(kv);
      kvC.value.buffer.asByteData().setUint64(0, 6);
      expect(() => c.uncompressKeyInEntry(kvC), throwsFormatException);
    });
  });
}
