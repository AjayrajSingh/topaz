// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../sledge.dart';
import '../sledge_connection_id.dart';
import '../transaction.dart';
import 'change.dart';
import 'document_id.dart';
import 'leaf_value.dart';
import 'uint8list_ops.dart';
import 'value_node.dart';
import 'value_observer.dart';

/// Represents structured data that can be stored in Sledge.
class Document implements ValueObserver {
  final Sledge _sledge;
  final DocumentId _documentId;
  ValueNode _value;
  final Map<Uint8List, LeafValue> _fields;
  final ConnectionId _connectionId;
  static const int _hashLength = 20;
  final StreamController<void> _changeController =
      new StreamController<void>.broadcast();

  /// Default constructor.
  Document(this._sledge, this._documentId)
      : _fields = new Uint8ListMapFactory<LeafValue>().newMap(),
        _connectionId = _sledge.connectionId {
    _value = _documentId.schema.newValue(_connectionId);

    _value.collectFields().forEach((final String key, final LeafValue value) {
      value.observer = this;

      // Hash the key
      final keyBytes =
          new Uint16List.fromList(key.codeUnits).buffer.asUint8List();
      Uint8List hashBytes =
          new Uint8List.fromList(sha1.convert(keyBytes).bytes);
      assert(hashBytes.length == _hashLength);
      // Insert [value] with the hashed key in [_fields].
      _fields[hashBytes] = value;
    });
  }

  /// Returns this document's documentId.
  DocumentId get documentId => _documentId;

  /// Get the change for all fields of [doc].
  static Change getChange(final Document doc) {
    return doc._getChange();
  }

  /// Ends the transaction for all fields of [doc].
  static void completeTransaction(final Document doc) {
    doc._completeTransaction();
  }

  /// Applies [change] to fields of [doc].
  static void applyChange(final Document doc, final Change change) {
    doc._applyChange(change);
  }

  /// Rolls back all local modifications on all fields of [doc].
  static void rollbackChange(final Document doc) {
    doc._rollbackChange();
  }

  /// Gets the change for all fields of this document.
  Change _getChange() {
    Change result = new Change();
    for (final prefix in _fields.keys) {
      result.addAll(_fields[prefix].getChange().withPrefix(prefix));
    }
    return result;
  }

  /// Ends the transaction for all fields of this document.
  void _completeTransaction() {
    for (final leafValue in _fields.values) {
      leafValue.completeTransaction();
    }
  }

  /// Applies change to fields of this document.
  void _applyChange(final Change change) {
    Map<Uint8List, Change> splittedChanges = change.splitByPrefix(_hashLength);
    for (final prefix in splittedChanges.keys) {
      _fields[prefix].applyChange(splittedChanges[prefix]);
    }
    _changeController.add(null);
  }

  Stream<void> get _onChange => _changeController.stream;

  /// Returns a stream, generating an event each time a document changes.
  static Stream<void> getOnChangeStream(final Document doc) => doc._onChange;
  
  /// Rolls back all local modifications on all fields of this document.
  void _rollbackChange() {
    for (final leafValue in _fields.values) {
      leafValue.rollbackChange();
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
