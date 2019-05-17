// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

Schema newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': Integer()
  };
  return Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('Verify that two unnamed DocumentId have different prefixes', () {
    Schema schema = newSchema();
    final id1 = DocumentId(schema);
    final id2 = DocumentId(schema);
    expect(id1.prefix, isNot(equals(id2.prefix)));
  });

  test('Verify that two identically named DocumentId have identical prefixes',
      () {
    Schema schema = newSchema();
    final id1 = DocumentId.fromIntId(schema, 42);
    final id2 = DocumentId.fromIntId(schema, 42);
    expect(id1.prefix, equals(id2.prefix));
  });

  test('Verify that an incorrect parameter results in an exception', () {
    Schema schema = newSchema();
    final list = <int>[];
    expect(() => DocumentId(schema, list), throwsA(anything));
  });
}
