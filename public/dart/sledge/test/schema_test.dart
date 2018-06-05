// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:sledge/sledge.dart';
import 'package:test/test.dart';

void main() {
  test('Create schemas and serialize them to json', () {
    // Create and test flat schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    expect(schema.jsonValue(),
        equals('{"someBool":"Boolean","someInteger":"Integer",}'));

    // TODO(jif): Split in a separate test.
    // Create and test schema that embeds another schema.
    Map<String, BaseType> schemaDescription2 = <String, BaseType>{
      'foo': schema
    };
    Schema schema2 = new Schema(schemaDescription2);
    expect(schema2.jsonValue(),
        equals('{"foo":{"someBool":"Boolean","someInteger":"Integer",},}'));
  });

  test('Instantiate and initialize a Sledge document', () {
    // Create schemas.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
    Map<String, BaseType> schemaDescription2 = <String, BaseType>{
      'foo': schema
    };
    Schema schema2 = new Schema(schemaDescription2);

    // Create a new Sledge document.
    Sledge sledge = new Sledge();
    dynamic doc = sledge.newDocument(schema2);

    // Read and write properties of a Sledge document.
    expect(doc.foo.someBool.value, equals(false));
    expect(doc.foo.someInteger.value, equals(0));
    doc.foo.someBool.value = true;
    doc.foo.someInteger.value = 42;
    expect(doc.foo.someBool.value, equals(true));
    expect(doc.foo.someInteger.value, equals(42));
  });

  test('LastWriteWin basic types.', () {
    // Create schemas.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer(),
      'someDouble': new Double(),
      'someString': new LastOneWinString()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = new Sledge();
    dynamic doc = sledge.newDocument(schema);

    // Read and write properties of a Sledge document.
    expect(doc.someBool.value, equals(false));
    expect(doc.someInteger.value, equals(0));
    expect(doc.someDouble.value, equals(0.0));
    expect(doc.someString.value, equals(''));
    doc.someBool.value = true;
    doc.someInteger.value = 42;
    doc.someDouble.value = 10.5;
    doc.someString.value = 'abacaba';
    expect(doc.someBool.value, equals(true));
    expect(doc.someInteger.value, equals(42));
    expect(doc.someDouble.value, equals(10.5));
    expect(doc.someString.value, equals('abacaba'));
  });

  test('Integration of PosNegCounter with Sledge', () {
    // Create Schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'cnt': new IntCounter(),
      'cnt_d': new DoubleCounter()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = new Sledge();
    dynamic doc = sledge.newDocument(schema);

    // Modify and get value of PosNegCounter.
    expect(doc.cnt.value, equals(0));
    expect(doc.cnt_d.value, equals(0.0));
    doc.cnt.add(5);
    expect(doc.cnt.value, equals(5));
    doc.cnt.add(-3);
    doc.cnt_d.add(-5.2);
    expect(doc.cnt.value, equals(2));
    expect(doc.cnt_d.value, equals(-5.2));
    doc.cnt_d.add(3.12);
    expect(doc.cnt_d.value, equals(-2.08));
  });
}
