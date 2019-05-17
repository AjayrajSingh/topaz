// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'inspect.dart';

/// A named node in the Inspect tree that can have [Node]s and
/// properties under it.
class Node {
  /// The VMO index of this node.
  /// @nodoc
  @visibleForTesting
  final int index;

  /// The writer for the underlying VMO.
  ///
  /// Will be set to null if the Node has been deleted or could not be
  /// created in the VMO.
  /// If so, all actions on this Node should be no-ops and not throw.
  VmoWriter _writer;

  final _properties = <String, Property>{};
  final _children = <String, Node>{};

  /// Creates a [Node] with [name] under the [parentIndex].
  ///
  /// Private as an implementation detail to code that understands VMO indices.
  /// Client code that wishes to create [Node]s should use [child].
  Node._(String name, int parentIndex, this._writer)
      : index = _writer.createNode(parentIndex, name) {
    if (index == invalidIndex) {
      _writer = null;
    }
  }

  /// Wraps the special root node.
  Node._root(this._writer) : index = _writer.rootNode;

  /// Creates a Node that never does anything.
  ///
  /// These are returned when calling createChild on a deleted [Node].
  Node._deleted()
      : _writer = null,
        index = invalidIndex;

  bool get _isDeleted => _writer == null;

  /// Returns a child [Node] with [name].
  ///
  /// If a child with [name] already exists and was not deleted, this
  /// method returns it. Otherwise, it creates a new [Node].
  Node child(String name) {
    if (_writer == null) {
      return Node._deleted();
    }
    // TODO(cphoenix): Tell parents when deleted, instead of asking children.
    // Asking children allows the map to grow without limit as children are
    // created and deleted (e.g. ring buffer).
    if (_children.containsKey(name) && !_children[name]._isDeleted) {
      return _children[name];
    }
    return _children[name] = Node._(name, index, _writer);
  }

  /// Deletes this node and any children from underlying storage.
  ///
  /// After a node has been deleted, all calls on it and its children have
  /// no effect and do not result in an error. Calls on a deleted node that
  /// return a Node or property return an already-deleted object.
  void delete() {
    if (_writer == null) {
      return;
    }
    _properties
      ..forEach((_, property) => property.delete())
      ..clear();
    _children
      ..forEach((_, node) => node.delete())
      ..clear();

    _writer.deleteEntity(index);
    _writer = null;
  }

  /// Returns a [StringProperty] with [name] on this node.
  ///
  /// If a [StringProperty] with [name] already exists and is not deleted,
  /// this method returns it.
  ///
  /// Otherwise, it creates a new property initialized to the empty string.
  ///
  /// Throws [InspectStateError] if a non-deleted property with [name] already
  /// exists but it is not a [StringProperty].
  StringProperty stringProperty(String name) {
    if (_writer == null) {
      return StringProperty._deleted();
    }
    if (_properties.containsKey(name) && !_properties[name]._isDeleted) {
      if (_properties[name] is! StringProperty) {
        throw InspectStateError("Can't create StringProperty named $name;"
            ' a different type exists.');
      }
      return _properties[name];
    }
    return _properties[name] = StringProperty._(name, index, _writer);
  }

  /// Returns a [ByteDataProperty] with [name] on this node.
  ///
  /// If a [ByteDataProperty] with [name] already exists and is not deleted,
  /// this method returns it.
  ///
  /// Otherwise, it creates a new property initialized to the empty
  /// byte data container.
  ///
  /// Throws [InspectStateError] if a non-deleted property with [name] already exists
  /// but it is not a [ByteDataProperty].
  ByteDataProperty byteDataProperty(String name) {
    if (_writer == null) {
      return ByteDataProperty._deleted();
    }
    if (_properties.containsKey(name) && !_properties[name]._isDeleted) {
      if (_properties[name] is! ByteDataProperty) {
        throw InspectStateError("Can't create ByteDataProperty named $name;"
            ' a different type exists.');
      }
      return _properties[name];
    }
    return _properties[name] = ByteDataProperty._(name, index, _writer);
  }

  /// Returns an [IntProperty] with [name] on this node.
  ///
  /// If an [IntProperty] with [name] already exists and is not
  /// deleted, this method returns it.
  ///
  /// Otherwise, it creates a new property initialized to 0.
  ///
  /// Throws [InspectStateError] if a non-deleted property with [name]
  /// already exists but it is not an [IntProperty].
  IntProperty intProperty(String name) {
    if (_writer == null) {
      return IntProperty._deleted();
    }
    if (_properties.containsKey(name) && !_properties[name]._isDeleted) {
      if (_properties[name] is! IntProperty) {
        throw InspectStateError(
            "Can't create IntProperty named $name; a different type exists.");
      }
      return _properties[name];
    }
    return _properties[name] = IntProperty._(name, index, _writer);
  }

  /// Returns a [DoubleProperty] with [name] on this node.
  ///
  /// If a [DoubleProperty] with [name] already exists and is not
  /// deleted, this method returns it.
  ///
  /// Otherwise, it creates a new property initialized to 0.0.
  ///
  /// Throws [InspectStateError] if a non-deleted property with [name]
  /// already exists but it is not a [DoubleProperty].
  DoubleProperty doubleProperty(String name) {
    if (_writer == null) {
      return DoubleProperty._deleted();
    }
    if (_properties.containsKey(name) && !_properties[name]._isDeleted) {
      if (_properties[name] is! DoubleProperty) {
        throw InspectStateError("Can't create DoubleProperty named $name;"
            ' a different type exists.');
      }
      return _properties[name];
    }
    return _properties[name] = DoubleProperty._(name, index, _writer);
  }
}

/// RootNode wraps the root node of the VMO.
///
/// The root node has special behavior: Delete is a NOP.
///
/// This class should be hidden from the public API.
/// @nodoc
class RootNode extends Node {
  /// Creates a Node wrapping the root of the Inspect hierarchy.
  RootNode(VmoWriter writer) : super._root(writer);

  /// Deletes of the root are NOPs.
  @override
  void delete() {}
}
