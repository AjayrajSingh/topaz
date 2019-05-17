// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:typed_data';

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:sledge/src/uint8list_ops.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/storage_state.dart';

void main() async {
  setupLogger();

  test('Empty storage state.', () async {
    StorageState storage = StorageState();
    expect(storage.getEntries(getUint8ListFromString('')).length, equals(0));
    expect(storage.getEntries(getUint8ListFromString('AA')).length, equals(0));
  });

  test('getEntries returns KVs in lexical order.', () async {
    final List<KeyValue> keyValues = <KeyValue>[];
    Uint8List unused = getUint8ListFromString('');
    keyValues
      ..add(KeyValue(getUint8ListFromString('AAB'), unused))
      ..add(KeyValue(getUint8ListFromString('Z'), unused))
      ..add(KeyValue(getUint8ListFromString('AABC'), unused))
      ..add(KeyValue(getUint8ListFromString('ZAA'), unused))
      ..add(KeyValue(getUint8ListFromString('AAA'), unused))
      ..add(KeyValue(getUint8ListFromString('ABAA'), unused));

    StorageState storage = StorageState()
      ..applyChange(Change(keyValues));

    final entries = storage.getEntries(getUint8ListFromString('AA'));
    expect(entries.length, equals(3));
    expect(entries[0].key, equals(getUint8ListFromString('AAA')));
    expect(entries[1].key, equals(getUint8ListFromString('AAB')));
    expect(entries[2].key, equals(getUint8ListFromString('AABC')));
  });
}
