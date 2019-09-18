# The Sledge library.

The goal of this library is to offer a high level API to Ledger, with
functionalities including:
* Storing structured data in Ledger.
* Primitives with automatic conflicts resolution strategies.
* Ability to run queries.

## Assumptions

To speed up the implementation of Sledge, the following assumptions were made:

* Only Sledge uses Ledger.
* Only one Ledger instance is used per process.

These assumptions will be lifted later on.

## User guide

### Creating a sledge instance

The first step in using Sledge is to create a new Sledge instance.
```dart
  import 'package:sledge/sledge.dart';
  ...
  Sledge sledge = Sledge(componentContext);
```

Alternatively, if using Sledge from a Module:
```dart
Sledge sledge = Sledge.fromModule(moduleContext);
```

### Writing a document

Writing a document to Sledge is done in 3 steps:
1. Create a Schema.
```dart
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someField': Boolean(),
      'someOtherField': Integer()
    };
    Schema schema = Schema(schemaDescription);
```
2. Create a DocumentId
A DocumentID uniquely identifies a Document. A unique DocumentID can be created like so:
```dart
    DocumentId id = DocumentId(schema);
```
Alternatively, a DocumentID that must not be random can be created like so:
```dart
    DocumentId id = DocumentId.fromIntId(schema, 2018);
```
3. Create and write to a document
```dart
    await sledge.runInTransaction(() async {
      Document doc = await sledge.getDocument(id);
      doc['someField'].value = true;
      doc['someOtherField'].value = 42;
    });
```

### Reading a document

Reading a document can be done by executing a query:
```dart
    // Read all Documents that have the Schema `schema`.
    await sledge.runInTransaction(() async {
      final List<Document> documents =
          awaitsledge.getDocuments(Query(schema));
    });
```

Alternatively, if the ID of a Document is known, it can be read directly
using `Sledge.getDocument`:
```dart
    await sledge.runInTransaction(() async {
      Document doc = await sledge.getDocument(id);
      assert(doc['someField'].value == true);
      assert(doc['someOtherField'].value == 42);
    });
```

## Inner workings

### Types and Schemas

The structure of the data stored in Ledger is defined using `Schemas`.
`Schemas` map strings to `Types`.
The available `Types` are: `Boolean`, `Integer`, `Double`, `Schemas`,
`LastOneWinsString`, `LastOneWinsUint8List`, `IntCounter`,
`DoubleCounter`, `BytelistMap`, `BytelistSet`.

### Values

`Schemas` describe the structures, but they can't hold any data.
To store data we can create `Values` from `Schemas`.
Every `Type` has an associated `Value`, for example:
  * Boolean -> BooleanValue
  * Integer -> IntegerValue
  * Schema -> NodeValue

### Documents

Documents wrap values and offer facilities to interact with Sledge.

### Queries

Queries allow obtaining all the Documents of a given Schema, optionally filtering
the results according to a set of criteria.

An exhaustive demonstration of the Querying capabilities and syntax can be
found in the [unittests for Queries](test/query/query_test.dart).
The QueryBuilder class exists to make Query creation easier.

Currently Queries are not accelerated using indexes, so the complexity of
running queries is in O(number of Documents of the given Schema).
With indexes, the complexity would be O(number of results of the Query).

## Testing

### Host-side tests

These tests run on the host and use a fake Ledger.
```
cd $FUCHSIA_DIR
# Debug mode should be activated and the topaz test packages should be included, e.g.
# fx set x64 out/debug-x64 --args=is_debug=true --packages=topaz/packages/all
fx build
fx run-host-tests dart_sledge_tests
```

When testing is complete, reset to default packages with:
```
fx set x64 $FUCHSIA_DIR/out/release-x64 --args=is_debug=false
```

### Device-side integration tests

To locally run these tests:

```
fx set x64 --product ermine --monolith topaz/packages/all --monolith topaz/packages/tests/all
fx build
fx run-test sledge_integration_tests
```

The results of the tests are visible in the logs:
```
fx syslog
```