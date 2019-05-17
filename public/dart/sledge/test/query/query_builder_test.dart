// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

Schema _newSchema() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': Integer(),
  };
  return Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('Verify exceptions', () async {
    Schema schema = _newSchema();
    QueryBuilder qb = QueryBuilder(schema)..addEqual('a', 1);
    // Test adding multiple restrictions on the same field.
    expect(() => qb.addEqual('a', 2), throwsArgumentError);
    // Test passing an unsuported type.
    expect(() => qb.addEqual('b', <int>[]), throwsArgumentError);
  });
}
