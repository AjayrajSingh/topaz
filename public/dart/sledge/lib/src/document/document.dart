// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../sledge.dart';
import '../sledge_connection_id.dart';
import '../transaction.dart';
import 'base_value.dart';
import 'change.dart';
import 'document_id.dart';
import 'uint8list_ops.dart';
import 'value_node.dart';
import 'value_observer.dart';

/// Represents structured data that can be stored in Sledge.
class Document implements ValueObserver {
  final Sledge _sledge;
  final DocumentId _documentId;
  ValueNode _value;
  final Map<Uint8List, BaseValue> _fields;
  final ConnectionId _connectionId;
  static const int _hashLength = 20;

  /// Default constructor.
  Document(this._sledge, this._documentId)
      : _fields = new Uint8ListMapFactory<BaseValue>().newMap(),
        _connectionId = _sledge.connectionId {
    _value = _documentId.schema.newValue(_connectionId);

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

  /// Get the change for all fields of doc.
  static Change getChange(final Document doc) {
    return doc._getChange();
  }

  /// Applies change to fields of document.
  static void applyChange(final Document doc, final Change change) {
    doc._applyChange(change);
  }

  /// Gets the change for all fields of document.
  Change _getChange() {
    Change result = new Change();
    for (final prefix in _fields.keys) {
      result.addAll(_fields[prefix].getChange().withPrefix(prefix));
    }
    return result;
  }

  /// Applies change to fields of document.
  void _applyChange(final Change change) {
    Map<Uint8List, Change> splittedChanges = change.splitByPrefix(_hashLength);
    for (final prefix in splittedChanges.keys) {
      _fields[prefix].applyChange(splittedChanges[prefix]);
    }
  }

  @override
  void valueWasChanged() {
    Transaction currentTransaction = _sledge.currentTransaction;
    if (currentTransaction == null) {
      throw new StateError('Value changed outside of transaction.');
    }
    currentTransaction.documentWasModified(this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return _value.noSuchMethod(invocation);
  }
}
