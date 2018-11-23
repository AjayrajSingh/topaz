// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../uint8list_ops.dart';
import 'converter.dart';

// Length of a bytelist, written on edge to value node.
// Bytelist content is: {1}{timetamp}, {timestamp} is 8 bytes long.
const _nodeValueSuffixLength = 9;
const _listEquality = const ListEquality();

/// Type of child.
enum ChildType {
  /// Left child.
  left,

  /// Value stored in current node.
  value,

  /// Right child.
  right
}

/// Class to represent path from the root to some node in OrderedList implicit tree.
class OrderedListTreePath implements Comparable<OrderedListTreePath> {
  final Uint8List _data;

  /// Default constructor.
  OrderedListTreePath(this._data);

  /// Constructor from [parent] and additional parts of path.
  OrderedListTreePath.fromParent(
      OrderedListTreePath parent, List<Uint8List> labels)
      : this(concatListOfUint8Lists([parent._data]..addAll(labels)));

  /// Creates OrderedListTreePath corresponding to tree root.
  OrderedListTreePath.root() : this(new Uint8List(_nodeValueSuffixLength));

  /// Checks if node is a child of a [parent].
  bool isDescendant(OrderedListTreePath parent) {
    if (_data.length <= parent._data.length) {
      return false;
    }
    int prefixLen = parent._data.length - _nodeValueSuffixLength;
    for (int i = 0; i < prefixLen; i++) {
      if (parent._data[i] != _data[i]) {
        return false;
      }
    }
    return true;
  }

  /// Returns path to parent implicit node, for value node.
  OrderedListTreePath parentPath() {
    // Remove appendix corresponding to value from path.
    return new OrderedListTreePath(new Uint8List.fromList(
        _data.getRange(0, _data.length - _nodeValueSuffixLength).toList()));
  }

  /// Returns OrderedListTreePath representing child of this.
  OrderedListTreePath getChild(
      ChildType side, Uint8List instanceId, Uint8List timestamp) {
    return new OrderedListTreePath.fromParent(
        // ----------------
        // Path to implicit node:
        // 1. path to parent implicit node
        parentPath(),
        [
          // 2. direction ([left] or [right]).
          new Uint8List.fromList([side.index]),
          // 3. id of current instance
          instanceId,
          // ----------------
          // Appendix for path to value:
          // 1. direction ([value])
          new Uint8List.fromList([ChildType.value.index]),
          // 2. timestamp
          timestamp
        ]);
  }

  @override
  int compareTo(OrderedListTreePath p) {
    for (int i = 0; i < min(_data.length, p._data.length); i++) {
      if (_data[i] != p._data[i]) {
        return _data[i].compareTo(p._data[i]);
      }
    }
    return _data.length.compareTo(p._data.length);
  }

  @override
  int get hashCode => _listEquality.hash(_data);

  @override
  bool operator ==(dynamic p) => compareTo(p) == 0;
}

/// Converter for OrderedListTreePath.
class OrderedListTreePathConverter implements Converter<OrderedListTreePath> {
  /// Constructor.
  const OrderedListTreePathConverter();

  @override
  OrderedListTreePath get defaultValue =>
      new OrderedListTreePath(new Uint8List(0));

  @override
  OrderedListTreePath deserialize(final Uint8List x) =>
      new OrderedListTreePath(x);

  @override
  Uint8List serialize(final OrderedListTreePath x) => x._data;
}

/// Public const instance of OrderedListTreePathConverter.
const OrderedListTreePathConverter orderedListTreePathConverter =
    const OrderedListTreePathConverter();
