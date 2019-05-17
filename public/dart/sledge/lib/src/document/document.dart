// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import '../sledge.dart';
import '../sledge_connection_id.dart';
import '../transaction.dart';
import '../uint8list_ops.dart';
import 'change.dart';
import 'document_id.dart';
import 'leaf_value.dart';
import 'node_value.dart';
import 'value_observer.dart';
import 'values/last_one_wins_value.dart';

enum _DocumentFieldType { public, private }

/// The state a document is in.
enum DocumentState {
  /// The document is available for reading and writing.
  available,

  /// The document has been scheduled for deletion in the current transaction.
  /// Reading and writing to the document is forbidden.
  pendingDeletion,

  /// The document has been deleted.
  /// Reading and writing to the document is forbidden.
  deleted
}

/// Represents structured data that can be stored in Sledge.
class Document implements ValueObserver {
  final Sledge _sledge;
  final DocumentId _documentId;
  NodeValue _value;
  final Map<Uint8List, LeafValue> _fields;
  final ConnectionId _connectionId;
  static const int _identifierLength = 21;
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  /// A value that is set to true for all documents that exist.
  /// If the Document object was created in a rollbacked transaction, then this
  /// field is false and all operations on this object are invalid.
  final LastOneWinsValue<bool> _documentExists = LastOneWinsValue<bool>();

  DocumentState _state = DocumentState.available;

  /// The name of the private field holding [_documentExists].
  static const String _documentExistsFieldName = 'documentExists';

  /// Default constructor.
  Document(this._sledge, this._documentId)
      : _fields = newUint8ListMap<LeafValue>(),
        _connectionId = _sledge.connectionId {
    _value = _documentId.schema.newValue(_connectionId);

    // Add to [_fields] all the public fields of [_value].
    _value.collectFields().forEach((final String key, final LeafValue value) {
      Uint8List identifier =
          _createIdentifierForField(key, _DocumentFieldType.public);
      assert(identifier.length == _identifierLength);
      _fields[identifier] = value;
    });

    // Add to [_fields] the private fields.
    Uint8List documentExistsValueIdentifier = _createIdentifierForField(
        _documentExistsFieldName, _DocumentFieldType.private);
    _fields[documentExistsValueIdentifier] = _documentExists;

    // Observe all the values contained by [_fields].
    _fields.forEach((Uint8List key, LeafValue value) {
      value.observer = this;
    });

    makeExist();
  }

  Uint8List _createIdentifierForField(String key, _DocumentFieldType type) {
    Uint8List hashOfKey = hash(getUint8ListFromString(key));
    Uint8List prefix = Uint8List.fromList([type.index]);
    return concatUint8Lists(prefix, hashOfKey);
  }

  /// Returns this document's documentId.
  DocumentId get documentId => _documentId;

  /// Returns the state the document is in.
  DocumentState get state => _state;

  /// Gets the change for all fields of this document.
  Change getChange() {
    Change result = Change();
    for (final field in _fields.entries) {
      result.addAll(field.value.getChange().withPrefix(field.key));
    }
    return result;
  }

  /// Ends the transaction for all fields of this document.
  void completeTransaction() {
    for (final leafValue in _fields.values) {
      leafValue.completeTransaction();
    }
    if (_state == DocumentState.pendingDeletion) {
      _state = DocumentState.deleted;
      // Allows the Dart VM to free some memory.
      _fields.clear();
      // TODO: evaluate if `_changeController` needs to be updated.
      // TODO: evaluate if the cache of Documents needs to be updated.
    }
  }

  /// Applies [change] to fields of this document.
  void applyChange(final Change change) {
    if (_state == DocumentState.available) {
      Map<Uint8List, Change> splittedChanges =
          change.splitByPrefix(_identifierLength);
      for (final splittedChange in splittedChanges.entries) {
        _fields[splittedChange.key].applyChange(splittedChange.value);
      }
    }
    _changeController.add(null);
  }

  /// Returns a stream generating an event each time a document changes.
  Stream<void> get onChange => _changeController.stream;

  /// Rolls back all local modifications on the state and on all fields of
  /// this document.
  void rollbackChange() {
    for (final leafValue in _fields.values) {
      leafValue.rollbackChange();
    }
    if (_state == DocumentState.pendingDeletion) {
      _state = DocumentState.available;
    }
  }

  /// Throws an exception if the document is in an invalid state.
  void _checkExistsState() {
    if (!_documentExists.value) {
      throw StateError('Value access to a non-existing document.');
    }
    if (_state != DocumentState.available) {
      throw StateError("Can't access a document that is deleted.");
    }
  }

  void _changeState() {
    _checkExistsState();
    Transaction currentTransaction = _sledge.currentTransaction;
    if (currentTransaction == null) {
      throw StateError('Document was changed outside of a transaction.');
    }
    currentTransaction.documentWasModified(this);
  }

  /// Sets [_documentExists] to |true| so that Ledger has a trace that this
  /// document was created. This makes the Document object valid.
  void makeExist() {
    _documentExists.value = true;
  }

  /// Deletes the document.
  void delete() {
    _changeState();
    _state = DocumentState.pendingDeletion;
  }

  @override
  void valueWasChanged() {
    _changeState();
  }

  /// Returns the Value associated with [fieldName].
  /// If [fieldName] does not have any associated Value, an ArgumentError
  /// exception is thrown.
  dynamic operator [](String fieldName) {
    _checkExistsState();
    return _value[fieldName];
  }
}
