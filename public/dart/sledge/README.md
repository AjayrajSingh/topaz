# The Sledge library.

The goal of this library is to offer a high level API to Ledger, with
functionalities including:
* Storing structured data in Ledger.
* Primitives with automatic conflicts resolution strategies.
* Ability to run efficient queries.

## Inner workings

### Types and Schemas

The structure of the data stored in Ledger is defined using *Schemas*.
*Schemas* map strings to *Types*.
Examples of *Types* are: *Boolean*, *Integer*, *Schemas*.

An example of a schema, written as a JSON object:
```
{
  "foo" : "Integer",
  "bar" : {
            "qux" : "Boolean"
          }
}
```

### Values

*Schemas* describe the structures, but they can't hold any data.
To store data we can create *Values* from *Schemas*.
Every *Type* has an associated *Value*:
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
