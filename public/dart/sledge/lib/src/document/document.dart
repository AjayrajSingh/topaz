// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../sledge.dart';
import '../transaction.dart';
import 'base_value.dart';
import 'change.dart';
import 'document_id.dart';
import 'uint8list_ops.dart';
import 'value_node.dart';
import 'value_observer.dart';

// TODO: Use the |_sledge| and |_documentId| fields.
// TODO: Use the |_put| and |_applyChanges| methods.
// ignore_for_file: unused_field, unused_element

/// Represents structured data that can be stored in Sledge.
class Document implements ValueObserver {
  final Sledge _sledge;
  final DocumentId _documentId;
  ValueNode _value;
  final Map<Uint8List, BaseValue> _fields;
  static const int _hashLength = 20;

  /// Default constructor.
  Document(this._sledge, this._documentId)
      : _fields = new Uint8ListMapFactory<BaseValue>().newMap() {
    _value = _documentId.schema.newValue();

    _value.collectFields().forEach((final String key, final BaseValue value) {
      value.observer = this;

      // Hash the key
      final keyBytes =
          new Uint16List.fromList(key.codeUnits).buffer.asUint8List();
      Uint8List hashBytes =
          new Uint8List.fromList(sha1.convert(keyBytes).bytes);
      assert(hashBytes.length == _hashLength);
      // Insert |value| with the hashed key in |_fields|.
      _fields[hashBytes] = value;
    });
  }

  /// Returns this document's documentId.
  DocumentId get documentId => _documentId;

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
  void valueWasChanged() {
    Transaction transaction = _sledge.transaction;
    if (transaction == null) {
      throw new StateError('Value changed outside of transaction.');
    }
    transaction.documentWasModified(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _value.noSuchMethod(invocation);
  }
}
