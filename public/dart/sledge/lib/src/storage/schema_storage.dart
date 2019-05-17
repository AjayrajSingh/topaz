// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:fidl_fuchsia_ledger/fidl_async.dart' as ledger;

import '../schema/schema.dart';
import '../uint8list_ops.dart';
import 'kv_encoding.dart' as sledge_storage;

/// Returns the key used to store [schema] in Ledger.
Uint8List _schemaStorageKey(Schema schema) {
  final key = concatUint8Lists(
      sledge_storage.prefixForType(sledge_storage.KeyValueType.schema),
      schema.hash);
  assert(key.length == sledge_storage.typePrefixLength + Schema.hashLength);
  return key;
}

/// Stores [schema] into [page].
Future<void> saveSchemaToPage(Schema schema, ledger.Page page) {
  final Uint8List key = _schemaStorageKey(schema);

  String jsonString = json.encode(schema);
  final Uint8List value = getUint8ListFromString(jsonString);
  // TODO: handle the case where |value| is larger than the maximum allowed
  // size.
  return page.put(
    key,
    value,
  );
}
