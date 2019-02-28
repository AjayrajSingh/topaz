// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:fidl/fidl.dart' as $fidl;
import 'package:fidl_fidl_examples_bindingstest/fidl_async.dart';

class SuccessCase<T> {
  SuccessCase(this.input, this.type, this.bytes);

  final T input;
  final $fidl.FidlType<T> type;
  final Uint8List bytes;

  static void run<T>(String name, T input, $fidl.FidlType<T> type, Uint8List bytes) {
    group(name, () {
      new SuccessCase(input, type, bytes)
        .._checkEncode()
        .._checkDecode();
    });
  }

  void _checkEncode() {
    test('encode', () {
      final $fidl.Encoder $encoder = new $fidl.Encoder()
        ..alloc(type.encodedSize);
      type.encode($encoder, input, 0);
      final message = $encoder.message;
      expect(new Uint8List.view(message.data.buffer, 0, message.dataLength), equals(bytes));
    });
  }

  void _checkDecode() {
    test('decode', () {
      final $fidl.Decoder $decoder = new $fidl.Decoder(
        new $fidl.Message(new ByteData.view(bytes.buffer, 0, bytes.length), [], bytes.length, 0))
          ..claimMemory(type.encodedSize);
        final $actual = type.decode($decoder, 0);
        expect($actual, equals(input));
    });
  }
}

void main() {
  group('roundtrip', () {
    SuccessCase.run('empty-struct-sandwich',
      TestEmptyStructSandwich(
      before: 'before', es: EmptyStruct(), after: 'after'),
      kTestEmptyStructSandwich_Type,
      Uint8List.fromList([
        6, 0, 0, 0, 0, 0, 0, 0, // length of "before"
        255, 255, 255, 255, 255, 255, 255, 255, // "before" is present
        0,                   // empty struct zero field
        0, 0, 0, 0, 0, 0, 0, // 7 bytes of padding after empty struct, to align to 64 bits
        5, 0, 0, 0, 0, 0, 0, 0, // length of "after"
        255, 255, 255, 255, 255, 255, 255, 255, // "after" is present
        98, 101, 102, 111, 114, 101, // "before"
        0, 0, // 2 bytes of padding after "before", to align to 64 bits
        97, 102, 116, 101, 114, // "after" string
        0, 0, 0, // 3 bytes of padding after "after", to align to 64 bits
      ])
    );
  });
}
