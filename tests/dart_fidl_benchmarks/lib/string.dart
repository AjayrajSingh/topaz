// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl/fidl.dart';

import 'package:fidl_fidl_test_dart_benchmark/fidl_async.dart';

import './benchmark.dart';

const _asciiString = 'Jived fox nymph grabs quick waltz.\n'
    'Glib jocks quiz nymph to vex dwarf.\n'
    'Sphinx of black quartz, judge my vow.\n'
    'The five boxing wizards jump quickly.\n';
const _unicodeString = '以呂波耳本部止\n'
    '千利奴流乎和加\n'
    '餘多連曽津祢那\n'
    '良牟有為能於久\n'
    '耶万計不己衣天\n'
    '阿佐伎喩女美之\n'
    '恵比毛勢須';

Message encodeStringMessage(String str) {
  const type = kJustOneString_Type;
  final value = JustOneString(value: str);
  final Encoder encoder = Encoder()..alloc(type.encodedSize);
  type.encode(encoder, value, 0);
  return encoder.message;
}

String decodeStringMessage(Message message) {
  const type = kJustOneString_Type;
  final Decoder decoder = Decoder(message)..claimMemory(type.encodedSize);
  final struct = type.decode(decoder, 0);
  return struct.value;
}

/// Make a copy of the underlying buffers and lists in the message.
Message _copyMessage(Message message) {
  final data = ByteData(message.data.lengthInBytes);
  for (int i = 0; i < message.data.lengthInBytes; i++) {
    data.setUint8(i, message.data.getUint8(i));
  }

  return Message(data, List.from(message.handles), message.dataLength,
      message.handlesLength);
}

void addStringBenchmarks() {
  // The ASCII and Unicode example strings should be the same length when encoded to UTF-8.
  assert(Utf8Encoder().convert(_asciiString).length ==
      Utf8Encoder().convert(_unicodeString).length);

  benchmark('ascii string encoding', (run, teardown) {
    run(() => encodeStringMessage(_asciiString));
  });

  benchmark('unicode string encoding', (run, teardown) {
    run(() => encodeStringMessage(_unicodeString));
  });

  benchmark('ascii string decoding', (run, teardown) {
    final message = _copyMessage(encodeStringMessage(_asciiString));
    run(() => decodeStringMessage(message));
  });

  benchmark('unicode string decoding', (run, teardown) {
    final message = _copyMessage(encodeStringMessage(_unicodeString));
    run(() => decodeStringMessage(message));
  });
}
