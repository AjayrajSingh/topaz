// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../schema/schema.dart';
import '../uint8list_ops.dart' as utils;

/// Uniquely identifies a document.
class DocumentId {
  /// The schema of the document.
  final Schema schema;

  Uint8List _subId;
  static const int _subIdByteCount = 16;
  static const int _schemahashByteCount = 20;

  /// The length of the prefix.
  static const int prefixLength = _subIdByteCount + _schemahashByteCount;

  /// Default constructor.
  /// [identifier] uniquely identifies documents for the given schema.
  /// [identifier] must be 16 bytes long.
  /// If absent, a randomly generated [identifier] is used.
  DocumentId(this.schema, [Uint8List identifier]) {
    identifier ??= _randomByteArrayForSubIds();
    if (identifier.length != _subIdByteCount) {
      throw ArgumentError(
          'Identifier does not contain $_subIdByteCount bytes.'
          'Found ${identifier.length} bytes instead.');
    }
    _subId = Uint8List.fromList(identifier);
  }

  /// Convenience factory that builds a DocumentId from the [identifier]'s 8 lowest bytes.
  factory DocumentId.fromIntId(Schema schema, int identifier) {
    Uint8List bytes = Uint8List(_subIdByteCount)
      ..buffer.asByteData().setUint64(0, identifier, Endian.little);
    return DocumentId(schema, bytes);
  }

  /// Returns the [prefixLength] bytes long prefix to be used to store in Ledger the
  /// document identified with this DocumentId.
  Uint8List get prefix {
    Uint8List prefix = Uint8List(_schemahashByteCount + _subIdByteCount);
    Uint8List schemaHash = schema.hash;
    assert(schemaHash.length == _schemahashByteCount);
    prefix..setAll(0, schemaHash)..setAll(_schemahashByteCount, _subId);
    return prefix;
  }

  /// Returns the identifier that can be used to create the same DocumentId.
  Uint8List get subId => Uint8List.fromList(_subId);

  static Uint8List _randomByteArrayForSubIds() =>
      utils.randomUint8List(_subIdByteCount);
}
