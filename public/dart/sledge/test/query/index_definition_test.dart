// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

Schema testSchema1() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': Integer(),
  };
  return Schema(schemaDescription);
}

Schema testSchema2() {
  final schemaDescription = <String, BaseType>{
    'a': Integer(),
    'b': Integer(),
    'c': Integer(),
  };
  return Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('IndexDefinition constructor.', () {
    final schema = testSchema1();
    IndexDefinition(schema);
    IndexDefinition(schema, fieldsWithEquality: <String>['a']);
    IndexDefinition(schema, fieldsWithEquality: <String>['a', 'b']);
    IndexDefinition(schema, fieldWithInequality: 'a');
    IndexDefinition(schema,
        fieldsWithEquality: <String>['a'], fieldWithInequality: 'b');
    expect(() => IndexDefinition(schema, fieldsWithEquality: <String>['']),
        throwsArgumentError);
    expect(() => IndexDefinition(schema, fieldsWithEquality: <String>['z']),
        throwsArgumentError);
    expect(
        () =>
            IndexDefinition(schema, fieldsWithEquality: <String>['a', 'a']),
        throwsArgumentError);
    expect(
        () => IndexDefinition(schema,
            fieldsWithEquality: <String>['a'], fieldWithInequality: 'a'),
        throwsArgumentError);
  });

  test('IndexDefinition serialization and deserialization.', () {
    final schema1 = testSchema1();
    final i1 = IndexDefinition(schema1,
        fieldsWithEquality: <String>['a'], fieldWithInequality: 'b');
    String jsonString = json.encode(i1);
    print(jsonString);
    final i2 = IndexDefinition.fromJson(json.decode(jsonString));
    expect(i1.hash, equals(i2.hash));
  });

  test('IndexDefinition hash.', () {
    final schema1 = testSchema1();
    final schema2 = testSchema2();
    final i1 = IndexDefinition(schema1, fieldsWithEquality: <String>['a']);
    final i2 = IndexDefinition(schema1, fieldsWithEquality: <String>['a']);
    final i3 = IndexDefinition(schema2, fieldsWithEquality: <String>['a']);
    final i4 = IndexDefinition(schema1, fieldsWithEquality: <String>['b']);
    expect(i1.hash, equals(i2.hash));
    expect(i1.hash, isNot(equals(i3.hash)));
    expect(i1.hash, isNot(equals(i4.hash)));
  });
}
