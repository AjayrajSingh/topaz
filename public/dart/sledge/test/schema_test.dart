// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

// TODO: investigate whether we can get rid of the implementation_imports.
// ignore_for_file: implementation_imports
import 'package:sledge/sledge.dart';
import 'package:sledge/src/document/change.dart';
import 'package:test/test.dart';

import 'fakes/fake_ledger_page.dart';

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

  test('Verify that two identical schemes result in identical hashes', () {
    Map<String, BaseType> schemaDescription1 = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Map<String, BaseType> schemaDescription2 = <String, BaseType>{
      'someInteger': new Integer(),
      'someBool': new Boolean(),
    };
    Schema schema1 = new Schema(schemaDescription1);
    Schema schema2 = new Schema(schemaDescription2);
    expect(schema1.hash, equals(schema2.hash));
  });

  test('Verify that two different schemes result in different hashes', () {
    Map<String, BaseType> schemaDescription1 = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer()
    };
    Map<String, BaseType> schemaDescription2 = <String, BaseType>{
      'someBool': new Boolean(),
    };
    Map<String, BaseType> schemaDescription3 = <String, BaseType>{
      'someBool_': new Boolean(),
      'someInteger': new Integer()
    };
    Schema schema1 = new Schema(schemaDescription1);
    Schema schema2 = new Schema(schemaDescription2);
    Schema schema3 = new Schema(schemaDescription3);
    expect(schema1.hash, isNot(equals(schema2.hash)));
    expect(schema1.hash, isNot(equals(schema3.hash)));
  });

  test('Verify that schemas can not be modified after their creation', () {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
    };
    Schema schema = new Schema(schemaDescription);
    Uint8List hash1 = schema.hash;
    schemaDescription['foo'] = new Integer();
    Uint8List hash2 = schema.hash;
    expect(hash1, equals(hash2));
  });

  test('Instantiate and initialize a Sledge document', () async {
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
    Sledge sledge = new Sledge.testing(new FakeLedgerPage());
    dynamic doc = sledge.newDocument(new DocumentId(schema2));

    // Read and write properties of a Sledge document.
    expect(doc.foo.someBool.value, equals(false));
    expect(doc.foo.someInteger.value, equals(0));
    await sledge.runInTransaction(() {
      doc.foo.someBool.value = true;
      doc.foo.someInteger.value = 42;
    });
    expect(doc.foo.someBool.value, equals(true));
    expect(doc.foo.someInteger.value, equals(42));
  });

  test('Last One Wins basic types.', () async {
    // Create schemas.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someBool': new Boolean(),
      'someInteger': new Integer(),
      'someDouble': new Double(),
      'someString': new LastOneWinsString()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = new Sledge.testing(new FakeLedgerPage());
    dynamic doc = sledge.newDocument(new DocumentId(schema));

    // Read and write properties of a Sledge document.
    expect(doc.someBool.value, equals(false));
    expect(doc.someInteger.value, equals(0));
    expect(doc.someDouble.value, equals(0.0));
    expect(doc.someString.value, equals(''));
    await sledge.runInTransaction(() {
      doc.someBool.value = true;
      doc.someInteger.value = 42;
      doc.someDouble.value = 10.5;
      doc.someString.value = 'abacaba';
    });
    expect(doc.someBool.value, equals(true));
    expect(doc.someInteger.value, equals(42));
    expect(doc.someDouble.value, equals(10.5));
    expect(doc.someString.value, equals('abacaba'));
  });

  test('Integration of PosNegCounter with Sledge', () async {
    // Create Schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'cnt': new IntCounter(),
      'cnt_d': new DoubleCounter()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = new Sledge.testing(new FakeLedgerPage());
    dynamic doc = sledge.newDocument(new DocumentId(schema));

    // Modify and get value of PosNegCounter.
    expect(doc.cnt.value, equals(0));
    expect(doc.cnt_d.value, equals(0.0));
    await sledge.runInTransaction(() {
      doc.cnt.add(5);
    });
    expect(doc.cnt.value, equals(5));
    await sledge.runInTransaction(() {
      doc.cnt.add(-3);
      doc.cnt_d.add(-5.2);
    });
    expect(doc.cnt.value, equals(2));
    expect(doc.cnt_d.value, equals(-5.2));
    await sledge.runInTransaction(() {
      doc.cnt_d.add(3.12);
    });
    expect(doc.cnt_d.value, equals(-2.08));
  });

  test('get and apply changes', () async {
    // Create Schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'name': new LastOneWinsString(),
      'number': new Integer(),
      'cnt': new IntCounter()
    };
    Schema schema = new Schema(schemaDescription);

    // Create two Sledge documents
    Sledge sledgeA = new Sledge.testing(new FakeLedgerPage()),
        sledgeB = new Sledge.testing(new FakeLedgerPage());
    dynamic docA = sledgeA.newDocument(new DocumentId(schema)),
        docB = sledgeB.newDocument(new DocumentId(schema));

    Change c1;
    await sledgeA.runInTransaction(() {
      docA
        ..name.value = 'value + counter'
        ..number.value = 5
        ..cnt.add(1);

      c1 = Document.put(docA);
    });

    Document.applyChanges(docB, c1);

    expect(docB.name.value, equals('value + counter'));
    expect(docB.number.value, equals(5));
    expect(docB.cnt.value, equals(1));
  });
}
