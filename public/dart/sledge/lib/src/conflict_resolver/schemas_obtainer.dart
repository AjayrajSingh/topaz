// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import '../uint8list_ops.dart';
import '../document/values/key_value.dart';
import '../schema/schema.dart';
import '../storage/kv_encoding.dart' as sledge_storage;

/// Returns a map between the hash of the individual schemas and the schemas.
Map<Uint8List, Schema> createSchemaMap(Set<KeyValue> schemaKeyValues) {
  final map = newUint8ListMap<Schema>();
  for (final schemaKeyValue in schemaKeyValues) {
    final schemaHash = getSublistView(schemaKeyValue.key,
        start: sledge_storage.typePrefixLength);
    String jsonString = utf8.decode(schemaKeyValue.value);
    map[schemaHash] = Schema.fromJson(json.decode(jsonString));
  }
  return map;
}
