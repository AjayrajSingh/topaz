# The Sledge library.

The goal of this library is to offer a high level API to Ledger, with
functionalities including:
* Storing structured data in Ledger.
* Primitives with automatic conflicts resolution strategies.
* Ability to run efficient queries. (WIP)

## Assumptions

To speed up the implementation of Sledge, the following assumptions were made:

* Only Sledge uses Ledger.
* Only one Ledger instance is used per process.

These assumptions will be fixed later on.

## User guide

### Creating a sledge instance

The first step in using Sledge is to create a new Sledge instance.
```dart
  import 'package:sledge/sledge.dart';
  ...
  Sledge sledge = new Sledge(componentContext);
```

Alternatively, if using Sledge from a Module:
```dart
Sledge sledge = new Sledge.fromModule(moduleContext));
```

### Writing a document

Writing a document to Sledge is done in 3 steps:
1. Create a Schema.
```dart
    Map<String, BaseType> schemaDescription = <String, BaseType>{
      'someField': new Boolean(),
      'someOtherField': new Integer()
    };
    Schema schema = new Schema(schemaDescription);
```
2. Create a DocumentId
```dart
    DocumentId id = new DocumentId.fromIntId(schema, 2018);
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

### Device-side tests

These tests run on a fuchsia and exercise real Ledger instances.
Require the `topaz/public/dart/sledge/sledge_testing_mod/package` package.
Running these tests is done by launching the `sledge_testing_mod` mod:
```
# The following statement will add a module named "bar" in a newly created
# story named "foo" and will run the sledge_testing_mod.
sessionctl --story_name="foo" --mod_name="bar" --mod_url="sledge_testing_mod" add_mod
```