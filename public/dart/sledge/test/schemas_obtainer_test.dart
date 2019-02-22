// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

// ignore_for_file: implementation_imports
import 'package:sledge/sledge.dart';
import 'package:sledge/src/conflict_resolver/schemas_obtainer.dart';
import 'package:sledge/src/uint8list_ops.dart';
import 'package:sledge/src/document/values/key_value.dart';
import 'package:sledge/src/storage/kv_encoding.dart' as sledge_storage;
import 'package:test/test.dart';

Map<String, BaseType> schemaDescriptionA() {
  return <String, BaseType>{
    'boolA': new Boolean(),
  };
}

Map<String, BaseType> schemaDescriptionB() {
  return <String, BaseType>{
    'boolB': new Boolean(),
  };
}

void main() {
  group('Test _createSchemaMap', () {
    test('empty set of KV', () {
      Map<Uint8List, Schema> map = createSchemaMap(<KeyValue>{});
      expect(map.isEmpty, equals(true));
    });
    test('2 schema KVs', () {
      Set<KeyValue> keyValues = <KeyValue>{};

      // Add 2 KeyValues encoding 2 different schemas.
      final schemaA = new Schema(schemaDescriptionA());
      final schemaB = new Schema(schemaDescriptionB());
      final schemaPrefix =
          sledge_storage.prefixForType(sledge_storage.KeyValueType.schema);
      final keyA = concatUint8Lists(schemaPrefix, schemaA.hash);
      final valueA = getUint8ListFromString(json.encode(schemaA));
      final keyB = concatUint8Lists(schemaPrefix, schemaB.hash);
      final valueB = getUint8ListFromString(json.encode(schemaB));
      keyValues
        ..add(new KeyValue(keyA, valueA))
        ..add(new KeyValue(keyB, valueB));

      Map<Uint8List, Schema> map = createSchemaMap(keyValues);
      expect(map.length, equals(2));
      expect(map[schemaA.hash], equals(schemaA));
      expect(map[schemaB.hash], equals(schemaB));
    });
  });
}
