// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/compressor.dart';
import 'package:sledge/src/document/values/key_value.dart';

import 'package:test/test.dart';

import 'matchers.dart';

void main() {
  setupLogger();

  group('Correct compression', () {
    test('KeyValue', () {
      final c = Compressor(), c1 = Compressor();
      final kv = KeyValue(
          Uint8List.fromList([1, 2, 3]), Uint8List.fromList([4, 5]));
      final kv2 = c.uncompressKeyInEntry(c1.compressKeyInEntry(kv));
      expect(kv2, KeyValueMatcher(kv));
    });

    test('Key', () {
      final c = Compressor();
      final key = Uint8List.fromList([3, 8, 2]);
      final keyUc = c.uncompressKey(c.compressKey(key));
      expect(keyUc, equals(key));

      final keyOth = Uint8List.fromList([3]);
      final keyOthUc = c.uncompressKey(c.compressKey(keyOth));
      expect(keyOthUc, equals(keyOth));
    });
  });

  group('Exceptions', () {
    test('Uncompress key', () {
      final c = Compressor(), c1 = Compressor();
      expect(
          () => c.uncompressKey(c1.compressKey(Uint8List.fromList([1, 2]))),
          throwsInternalError);
    });

    test('Uncompress short key', () {
      final c = Compressor();
      expect(() => c.uncompressKey(Uint8List.fromList([1, 2])),
          throwsInternalError);
    });

    test('Uncompress key value with wrong key length', () {
      final c = Compressor();
      final kv = KeyValue(
          Uint8List.fromList([1, 2, 3]), Uint8List.fromList([4, 5]));
      final kvC = c.compressKeyInEntry(kv);
      kvC.value.buffer.asByteData().setUint64(0, 6);
      expect(() => c.uncompressKeyInEntry(kvC), throwsInternalError);
    });
  });
}
