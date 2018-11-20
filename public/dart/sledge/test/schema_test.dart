// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:typed_data';

// TODO: investigate whether we can get rid of the implementation_imports.
// ignore_for_file: implementation_imports
import 'package:fidl_fuchsia_ledger/fidl.dart' as ledger;
import 'package:lib.app.dart/logging.dart';
import 'package:sledge/sledge.dart';
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/uint8list_ops.dart';
import 'package:test/test.dart';

import 'helpers.dart';

Map<String, BaseType> flatSchema() {
  return <String, BaseType>{
    'someBool': new Boolean(),
    'someInteger': new Integer()
  };
}

Map<String, BaseType> schemaWithEmbeddedSchema() {
  Schema schema = new Schema(flatSchema());
  return <String, BaseType>{'foo': schema, 'bar': new LastOneWinsString()};
}

void main() {
  setupLogger();

  test('Create flat schema', () {
    new Schema(flatSchema());
  });

  test('Create schema with embedded schema.', () {
    new Schema(schemaWithEmbeddedSchema());
  });

  test('Serialize and deserialize flat schema', () {
    Schema schema1 = new Schema(flatSchema());
    final json1 = json.encode(schema1);
    Schema schema2 = new Schema.fromJson(json.decode(json1));
    final json2 = json.encode(schema2);
    expect(json1, equals(json2));
  });

  test('Serialize and deserialize schema with embedded schema', () {
    Schema schema1 = new Schema(schemaWithEmbeddedSchema());
    final json1 = json.encode(schema1);
    Schema schema2 = new Schema.fromJson(json.decode(json1));
    final json2 = json.encode(schema2);
    expect(json1, equals(json2));
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

  test('Verify exception with invalid field names', () {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'foo.bar': new Boolean(),
    };
    expect(() {
      new Schema(schemaDescription);
    }, throwsA(const TypeMatcher<ArgumentError>()));
  });

  test('Verify fieldAtPath', () {
    final schema = new Schema(schemaWithEmbeddedSchema());
    expect(schema.fieldAtPath(null), equals(null));
    expect(schema.fieldAtPath(''), equals(null));
    expect(schema.fieldAtPath('.'), equals(null));
    expect(schema.fieldAtPath('..'), equals(null));
    expect(schema.fieldAtPath('xyz'), equals(null));
    expect(schema.fieldAtPath('foo'), TypeMatcher<Schema>());
    expect(schema.fieldAtPath('bar'), TypeMatcher<LastOneWinsString>());
    expect(schema.fieldAtPath('foo.'), equals(null));
    expect(schema.fieldAtPath('bar.'), equals(null));
    expect(schema.fieldAtPath('foo.someBool'), TypeMatcher<Boolean>());
    expect(schema.fieldAtPath('foo.someBool.'), equals(null));
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
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(new DocumentId(schema2));
    });
    // Read and write properties of a Sledge document.
    expect(doc['foo']['someBool'].value, equals(false));
    expect(doc['foo']['someInteger'].value, equals(0));
    await sledge.runInTransaction(() async {
      doc['foo']['someBool'].value = true;
      doc['foo']['someInteger'].value = 42;
    });
    expect(doc['foo']['someBool'].value, equals(true));
    expect(doc['foo']['someInteger'].value, equals(42));
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
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(new DocumentId(schema));
    });

    // Read and write properties of a Sledge document.
    expect(doc['someBool'].value, equals(false));
    expect(doc['someInteger'].value, equals(0));
    expect(doc['someDouble'].value, equals(0.0));
    expect(doc['someString'].value, equals(''));

    await sledge.runInTransaction(() async {
      doc['someBool'].value = true;
      doc['someInteger'].value = 42;
      doc['someDouble'].value = 10.5;
      doc['someString'].value = 'abacaba';
    });

    expect(doc['someBool'].value, equals(true));
    expect(doc['someInteger'].value, equals(42));
    expect(doc['someDouble'].value, equals(10.5));
    expect(doc['someString'].value, equals('abacaba'));
  });

  test('Integration of PosNegCounter with Sledge', () async {
    // Create Schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'cnt': new IntCounter(),
      'cnt_d': new DoubleCounter()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(new DocumentId(schema));
    });

    // Modify and get value of PosNegCounter.
    expect(doc['cnt'].value, equals(0));
    expect(doc['cnt_d'].value, equals(0.0));
    await sledge.runInTransaction(() async {
      doc['cnt'].add(5);
    });
    expect(doc['cnt'].value, equals(5));
    await sledge.runInTransaction(() async {
      doc['cnt'].add(-3);
      doc['cnt_d'].add(-5.2);
    });
    expect(doc['cnt'].value, equals(2));
    expect(doc['cnt_d'].value, equals(-5.2));
    await sledge.runInTransaction(() async {
      doc['cnt_d'].add(3.12);
    });
    expect(doc['cnt_d'].value, equals(-2.08));
  });

  // TODO: add tests for BytelistMap and BytelistSet.

  test('Integration of OrderedList with Sledge', () async {
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'list': new OrderedList()
    };
    Schema schema = new Schema(schemaDescription);

    // Create a new Sledge document.
    Sledge sledge = newSledgeForTesting();
    Document doc;
    await sledge.runInTransaction(() async {
      doc = await sledge.getDocument(new DocumentId(schema));
    });

    // Apply modifications to OrderedList.
    expect(doc['list'].toList(), equals([]));
    await sledge.runInTransaction(() async {
      doc['list'].insert(0, new Uint8List.fromList([1]));
    });
    expect(doc['list'].toList().length, equals(1));
    expect(doc['list'][0].toList(), equals([1]));
    await sledge.runInTransaction(() async {
      doc['list'].insert(1, new Uint8List.fromList([3]));
      doc['list'].insert(1, new Uint8List.fromList([2]));
    });
    expect(doc['list'].toList().length, equals(3));
    expect(doc['list'][0].toList(), equals([1]));
    expect(doc['list'][1].toList(), equals([2]));
    expect(doc['list'][2].toList(), equals([3]));
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
    Sledge sledgeA = newSledgeForTesting(), sledgeB = newSledgeForTesting();
    Document docA, docB;
    await sledgeA.runInTransaction(() async {
      docA = await sledgeA.getDocument(new DocumentId(schema));
    });
    await sledgeB.runInTransaction(() async {
      docB = await sledgeB.getDocument(new DocumentId(schema));
    });

    Change c1;
    await sledgeA.runInTransaction(() async {
      docA
        ..['name'].value = 'value + counter'
        ..['number'].value = 5
        ..['cnt'].add(1);

      c1 = docA.getChange();
    });

    docB.applyChange(c1);

    expect(docB['name'].value, equals('value + counter'));
    expect(docB['number'].value, equals(5));
    expect(docB['cnt'].value, equals(1));
  });

  test('put large list into set', () async {
    // Create Schema.
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'names': new BytelistSet(),
    };
    Schema schema = new Schema(schemaDescription);

    // Create two Sledge documents
    Sledge sledgeA = newSledgeForTesting(), sledgeB = newSledgeForTesting();
    Document docA, docB;
    await sledgeA.runInTransaction(() async {
      docA = await sledgeA.getDocument(new DocumentId(schema));
    });
    await sledgeB.runInTransaction(() async {
      docB = await sledgeB.getDocument(new DocumentId(schema));
    });

    final largeList = randomUint8List(10000);

    Change c1;
    await sledgeA.runInTransaction(() async {
      docA['names'].add(largeList);
      c1 = docA.getChange();
    });

    docB.applyChange(c1);
    expect(docB['names'].single, equals(largeList));
  });

  group('Rollback', () {
    test('rollback LastOneWinsValue', () async {
      // Create schemas.
      Map<String, BaseType> schemaDescription = <String, BaseType>{
        'someBool': new Boolean(),
        'someInteger': new Integer()
      };
      Schema schema = new Schema(schemaDescription);

      // Create a new Sledge document.
      SledgeForTesting sledge = newSledgeForTesting();
      Document doc;
      await sledge.runInTransaction(() async {
        doc = await sledge.getDocument(new DocumentId(schema));
      });
      // Read and write properties of a Sledge document.
      bool transactionSucceed = await sledge.runInTransaction(() async {
        doc['someInteger'].value = 14;
      });
      expect(transactionSucceed, true);
      expect(doc['someInteger'].value, equals(14));

      // Test case when commit fails.
      sledge.fakeLedgerPage.commitStatus = ledger.Status.ioError;
      transactionSucceed = await sledge.runInTransaction(() async {
        doc['someBool'].value = true;
        doc['someInteger'].value = 42;
      });
      expect(transactionSucceed, false);
      expect(doc['someBool'].value, equals(false));
      expect(doc['someInteger'].value, equals(14));

      // Check that after failed transaction we can get successful one.
      sledge.fakeLedgerPage.resetAllStatus();
      transactionSucceed = await sledge.runInTransaction(() async {
        doc['someInteger'].value = 8;
      });
      expect(transactionSucceed, true);
      expect(doc['someInteger'].value, equals(8));
    });

    test('rollback BytelistMap', () async {
      // Create schemas.
      Map<String, BaseType> schemaDescription = <String, BaseType>{
        'map': new BytelistMap(),
      };
      Schema schema = new Schema(schemaDescription);

      // Create a new Sledge document.
      SledgeForTesting sledge = newSledgeForTesting();
      Document doc;
      await sledge.runInTransaction(() async {
        doc = await sledge.getDocument(new DocumentId(schema));
      });
      // Read and write properties of a Sledge document.
      bool transactionSucceed = await sledge.runInTransaction(() async {
        doc['map']['a'] = new Uint8List.fromList([1, 2, 3]);
      });
      expect(transactionSucceed, true);
      expect(doc['map'].length, equals(1));

      // Test case when commit fails.
      sledge.fakeLedgerPage.commitStatus = ledger.Status.ioError;
      transactionSucceed = await sledge.runInTransaction(() async {
        doc['map']['a'] = new Uint8List.fromList([4]);
        doc['map']['foo'] = new Uint8List.fromList([1, 3]);
      });
      expect(transactionSucceed, false);
      expect(doc['map'].length, equals(1));
      expect(doc['map']['a'], equals([1, 2, 3]));

      // Check that after failed transaction we can get successful one.
      sledge.fakeLedgerPage.resetAllStatus();
      transactionSucceed = await sledge.runInTransaction(() async {
        doc['map']['foo'] = new Uint8List.fromList([1, 3]);
      });
      expect(transactionSucceed, true);
      expect(doc['map'].length, equals(2));
      expect(doc['map']['a'], equals([1, 2, 3]));
      expect(doc['map']['foo'], equals([1, 3]));

      transactionSucceed = await sledge.runInTransaction(() async {
        doc['map']['a'] = new Uint8List.fromList([3, 4]);
      });
      expect(transactionSucceed, true);
      expect(doc['map']['a'], equals([3, 4]));
    });
  });
}
