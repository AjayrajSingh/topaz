# Structured Entity Data

> Status: DRAFT

Modular's Entity model allows for the storage and retrieval of an Entity's data
that adheres to a specific contract used to translate content to and from
structured data. The contract for a view of the structured data is identified by
a key for a type that can be any string value. Generally the keys are URLs or a
reverse-DNS string that signals who owns the contract and where to find its
definition.

The translation between an Entity's raw content and it's structured data is a
**run-time construct**. An Entity's FIDL interface allows access to raw content
for a given type but the decoding of that data happens within the client
process. How an Entity client decodes and encodes structured data is not
enforced directly at the FIDL interfaces.

## Versioning

It's important to note that Entity clients using the same type key expect the
structured data to have the same exact contract. Versioning is not directly
supported but versioning information can be added to the type key if needed.
When versioning is required the following pattern might be useful.

* Non-versioned type: "com.fuchsia.color" the contract can and will break
  hurting compatibility unless all client usage is simultaneously updated. This
  might be okay or desireable for some in-tree development.
* Versioned type: "com.fuchsia.v1.color", the contract is pinned to "v1" in this
  case. There is an expectation that compatibility can be maintained or upgrade
  pain mitigated by the owner adding a new type key for updates, e.g.
  "com.fuchsia.v2.color"

## Schemas

For projects in the `//topaz` layer most of the contracts for structured Entity
data are implemented as library code available in `//topaz/public/lib/schemas`.

For in tree development new, public contracts (schemas & codecs) should be added
to this location unless there is a strong case for the contracts to be tied to an app or vendor. Centralizing the definition of these contracts this way helps prevent
duplication and divergent implementations.

### Entity Codecs

Topaz's schema Dart library exposes codecs that can be instantiated and used
with Entity interactions enabled via the ModuleDriver. If a Module or Agent
written in Dart needs to read or write Entity data it should use the codec for
the correct type to ensure compatibility between components. When reading an
Entity's content, codecs expose structured data wrapped in an instance of an
EntityData class holding primitive Dart types, e.g. `String`, `int`,
`List<String>`, etc.

### Vendor Specific Schemas

Contracts for structured data that is not expected to be exposed as a system
level, public type but still needs to be shared should be added to the project's
code as a package:

* Public contracts: `<layer>/app/<project>/public/lib/schemas/<lang>`
* Private contracts: `<layer>/app/<project>/lib/schemas/<lang>`

Type keys (URLs, reverse-DNS strings, mime, etc.) MUST be unique and should
obviously belong to the vendor:

* reverse-DNS (preferred): 'com.vendor.special-type'
* URL: 'https://api.vendor.com/special-type'
* mime: 'application/x-special-type+json'

## Adding New Entity Schemas

Tips for adding new schemas:

* New schemas should be added to `//topaz/public/lib/schemas` or the appropriate
  location as described above.
* Exports for Dart packages should have the type key in their path, e.g. this
  import should pull in all the necessary classes for schemas, codecs, and data
  `import 'package:lib.schemas/com.fuchsia.color.dart'`.
* Avoid adding any new dependencies.
* Try to only use primitive types within structured data.
* Avoid language specific constructs within structured data.
* Codecs should use corresponding schemas for validation during encoding and
  decoding.
