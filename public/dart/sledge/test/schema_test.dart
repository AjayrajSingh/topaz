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
}
