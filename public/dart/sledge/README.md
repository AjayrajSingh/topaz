# The Sledge library.

The goal of this library is to offer a high level API to Ledger, with
functionalities including:
* Storing structured data in Ledger.
* Primitives with automatic conflicts resolution strategies.
* Ability to run efficient queries. (WIP)

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
      dynamic doc = await sledge.getDocument(id);
      doc.someField.value = true;
      doc.someOtherField.value = 42;
    });
```

### Reading a document
```dart
    await sledge.runInTransaction(() async {
      dynamic doc = await sledge.getDocument(id);
      assert(doc.someField.value == true);
      assert(doc.someOtherField.value == 42);
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
  * Schema -> ValueNode

### Documents

Documents wrap values and offer facilities to interact with Sledge.

## Testing
To run the tests:
```
cd $FUCHSIA_DIR
# Debug mode should be activated and the topaz test packages should be included, e.g.
# fx set x64 out/debug-x64 --args=is_debug=true --packages=topaz/packages/all
fx build
scripts/run-dart-action.py test --out=`fx get-build-dir` --tree=//topaz/public/dart/sledge/*
```

When testing is complete, reset to default packages with:
```
fx set x64 $FUCHSIA_DIR/out/release-x64 --args=is_debug=false
```
