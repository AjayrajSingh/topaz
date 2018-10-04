// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

Schema testSchema1() {
  final schemaDescription = <String, BaseType>{
    'a': new Integer(),
    'b': new Integer(),
  };
  return new Schema(schemaDescription);
}

Schema testSchema2() {
  final schemaDescription = <String, BaseType>{
    'a': new Integer(),
    'b': new Integer(),
    'c': new Integer(),
  };
  return new Schema(schemaDescription);
}

void main() {
  setupLogger();

  test('IndexDefinition constructor.', () {
    final schema = testSchema1();
    new IndexDefinition(schema);
    new IndexDefinition(schema, fieldsWithEquality: <String>['a']);
    new IndexDefinition(schema, fieldsWithEquality: <String>['a', 'b']);
    new IndexDefinition(schema, fieldWithInequality: 'a');
    new IndexDefinition(schema,
        fieldsWithEquality: <String>['a'], fieldWithInequality: 'b');
    expect(() => new IndexDefinition(schema, fieldsWithEquality: <String>['']),
        throwsArgumentError);
    expect(() => new IndexDefinition(schema, fieldsWithEquality: <String>['z']),
        throwsArgumentError);
    expect(
        () =>
            new IndexDefinition(schema, fieldsWithEquality: <String>['a', 'a']),
        throwsArgumentError);
    expect(
        () => new IndexDefinition(schema,
            fieldsWithEquality: <String>['a'], fieldWithInequality: 'a'),
        throwsArgumentError);
  });

  test('IndexDefinition serialization and deserialization.', () {
    final schema1 = testSchema1();
    final i1 = new IndexDefinition(schema1,
        fieldsWithEquality: <String>['a'], fieldWithInequality: 'b');
    String jsonString = json.encode(i1);
    print(jsonString);
    final i2 = IndexDefinition.fromJson(json.decode(jsonString));
    expect(i1.hash, equals(i2.hash));
  });

  test('IndexDefinition hash.', () {
    final schema1 = testSchema1();
    final schema2 = testSchema2();
    final i1 = new IndexDefinition(schema1, fieldsWithEquality: <String>['a']);
    final i2 = new IndexDefinition(schema1, fieldsWithEquality: <String>['a']);
    final i3 = new IndexDefinition(schema2, fieldsWithEquality: <String>['a']);
    final i4 = new IndexDefinition(schema1, fieldsWithEquality: <String>['b']);
    expect(i1.hash, equals(i2.hash));
    expect(i1.hash, isNot(equals(i3.hash)));
    expect(i1.hash, isNot(equals(i4.hash)));
  });
}
