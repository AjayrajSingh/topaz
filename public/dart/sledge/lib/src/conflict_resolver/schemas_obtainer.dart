// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;

import '../document/uint8list_ops.dart';
import '../document/values/key_value.dart';
import '../ledger_helpers.dart';
import '../schema/schema.dart';
import '../storage/kv_encoding.dart' as sledge_storage;

/// Returns a mapping between the Schemas stored in [left] and [right] pages
/// and their hashes.
/// For example:
/// if [left] contains the schemas (s0, s1) and [right] contains the schemas
/// (s1, s2), then the returned map would be:
/// { hash(s0) : s0, hash(s1) : s1, hash(s2) : s2 }
Future<Map<Uint8List, Schema>> getMapOfAllSchemas(
    ledger.PageSnapshot left, ledger.PageSnapshot right) async {
  final futureLeftSchemasKVs = _getSchemaKeyValues(left);
  final futureRightSchemasKVs = _getSchemaKeyValues(right);
  final leftSchemasKVs = await futureLeftSchemasKVs;
  final rightSchemasKVs = await futureRightSchemasKVs;
  final allSchemas = leftSchemasKVs.union(rightSchemasKVs);
  return createSchemaMap(allSchemas);
}

/// Returns the set of Key Values encoding schemas stored in [snapshot].
Future<Set<KeyValue>> _getSchemaKeyValues(ledger.PageSnapshot snapshot) async {
  final schemaPrefix =
      sledge_storage.prefixForType(sledge_storage.KeyValueType.schema);
  final List<KeyValue> kvs =
      await getEntriesFromSnapshotWithPrefix(snapshot, schemaPrefix);
  return new Set.from(kvs);
}

/// Returns a map between the hash of the individual schemas and the schemas.
Map<Uint8List, Schema> createSchemaMap(Set<KeyValue> schemaKeyValues) {
  final map = newUint8ListMap<Schema>();
  for (final schemaKeyValue in schemaKeyValues) {
    final schemaHash = getSublistView(schemaKeyValue.key,
        start: sledge_storage.typePrefixLength);
    String jsonString = utf8.decode(schemaKeyValue.value);
    map[schemaHash] = new Schema.fromJson(json.decode(jsonString));
  }
  return map;
}
