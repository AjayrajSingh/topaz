// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

import '../schema/schema.dart';
import '../sledge.dart';
import 'base_value.dart';
import 'change.dart';
import 'document_id.dart';
import 'value_node.dart';

// TODO: Use the |_sledge| field and |_put|, |_applyChanges| methods.
// ignore_for_file: unused_field, unused_element

/// Represents structured data that can be stored in Sledge.
class Document {
  final Sledge _sledge;
  final Schema _schema;
  final DocumentId _documentId;
  ValueNode _value;
  final Map<Uint8List, BaseValue> _fields;
  static const int _hashLength = 20;

  /// Default constructor.
  Document(this._sledge, this._documentId)
      : _fields = new HashMap<Uint8List, BaseValue>(
            equals: new ListEquality().equals,
            hashCode: new ListEquality().hash),
        _schema = _documentId.schema {
    _value = _schema.newValue();
    Map<String, BaseValue> fields = _value.collectFields();
    for (final key in fields.keys) {
      final keyBytes =
          new Uint16List.fromList(key.codeUnits).buffer.asUint8List();
      Uint8List hashBytes =
          new Uint8List.fromList(sha1.convert(keyBytes).bytes);
      assert(hashBytes.length == _hashLength);
      _fields[hashBytes] = fields[key];
    }
  }

  /// Get a changes for all fields of doc.
  static Change put(final Document doc) {
    return doc._put();
  }

  /// Applies changes to fields of document.
  static void applyChanges(final Document doc, final Change change) {
    doc._applyChanges(change);
  }

  /// Gets a changes for all fields of document.
  Change _put() {
    Change result = new Change();
    for (final prefix in _fields.keys) {
      result.addAll(_fields[prefix].put().withPrefix(prefix));
    }
    return result;
  }

  /// Applies changes to fields of document.
  void _applyChanges(final Change change) {
    Map<Uint8List, Change> splittedChanges = change.splitByPrefix(_hashLength);
    for (final prefix in splittedChanges.keys) {
      _fields[prefix].applyChanges(splittedChanges[prefix]);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _value.noSuchMethod(invocation);
  }
}
