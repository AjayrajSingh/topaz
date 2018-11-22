// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../change.dart';
import '../leaf_value.dart';
import '../value_observer.dart';
import 'converted_change.dart';
import 'converter.dart';
import 'key_value_storage.dart';
import 'ordered_list_tree_path.dart';

/// Implementation of Ordered List CRDT.
///
/// The ordered List CRDT can be changed concurrently by multiple instances, each
/// associated with an instance ID. Changes from other instances are applied when
/// calling [applyChange], while changes from this instance can be retrieved by
/// calling [getChange].
//
// The contents of the list are stored using a KeyValueStorage. The values of
// the KeyValueStorage are the elements of the list, while the keys are created
// in such a way that their lexicographic order corresponds to the order of the
// elements of the list.
//
//  Key generation is based on an implicit tree structure, where edges are
//  directed from parent nodes towards child nodes. For each edge (v, u) there
//  is an associated bytelist f(v, u). For each node v there is an associated
//  bytelist F(v), which is the concatenation of bytelists associated with the
//  edges on path from root to v.
//
//  Example:
//
//    root -----> a -----> b -----> v
//                |
//                -------> u
//
//    F(v) = f(root, a) f(a, b) f(b, v)
//    F(u) = f(root, a) f(a, u)
//
//  The tree has nodes of two types:
//    Value nodes, for which:
//      f(p, v) = {1}{timestamp}
//
//    Implicit nodes, for which:
//      f(p, v) = {0|2}{instanceId}
//    The prefix of f(p, v) is 0 if (v) is a left child of (p) or 2 if it is a
//    right child.
//
//  Value nodes correspond to leaves, while implicit nodes are the internal
//  ones. There is a one-to-one correspondence between the elements of the list
//  and the set of value nodes. Every value node has an implicit node as a
//  parent that is created on the same instance as that value node.
//
//  Every implicit node has exactly one value child node. It might also have one
//  left and one right (implicit) nodes per instance.
//
//  Insertion:
//    In the most common case, a new element is inserted between two existing
//    ones. Let (v) be the new value node, and (left) and (right) be the nodes
//    of the previous and next elements correspondingly. Also, let (pleft) and
//    (pright) be their corresponding parents, both of them being, by
//    definition, implicit nodes.
//
//    If (pleft) is not an ancestor of (pright), then we add a new implicit node
//    (par_v) as a right child of (pleft) and (v) as the value node of (par_v):
//
//        root -----> pleft -----> left
//             |            |
//             |            - - -> par(v) - - -> v
//             |
//             -----> pright ----> right
//
//      We have now defined:
//
//        F(v) = F(pleft){2}{instanceId}{1}{timestamp}
//
//      The invariant of the keys being ordered in lexicographic order is maintained as:
//        1. F(left) = F(pleft){1}{timestamp}. So F(left) < F(v).
//        2. F(right) > F(pleft), and F(pleft) is not a prefix of F(right).
//          So F(right) > F(v).
//
//    Otherwise, i.e. when (pleft) is an ancestor of (pright), we insert a new
//    implicit node (par_v) as the left child of (pleft) and (v) as the value of
//    that node:
//
//        root -----> pleft -----> left
//                          |
//                          |             - - -> par(v) - - -> v
//                          |             |
//                          ------> pright ----> right
//
//      We have now defined:
//
//        F(v) = F(pright){0}{instanceId}{1}{timestamp}
//
//      The invariant of the lexicographic order of the keys is still maintained since:
//        1. F(right) = F(pright){1}{timestamp}. So F(right) > F(v).
//        2. F(left) < F(right), and F(left) can't start with F(pright),
//          so F(left) < F(pright) < F(v).
//
//
//  instanceId:
//    instanceIds are introduced to handle concurrent insertions on different
//    instances. Last instanceId in the path to the node should correspond to
//    the instance that created that node.
//
//  timestamp:
//    timestamps are introduced to avoid tombstones. If some key is deleted,
//    then it should never be inserted again. In other case conflict might
//    happen. The same key may be inserted only on the same instance, so
//    incremental timer per instance is applicable.
//
// TODO:
// Now each implicit node have only one value child. It should be changed. And
// at the same time value nodes should get able to have implicit node as a
// child. And left/right edges should have no id written on them.
//
// TODO: handle null values in CRDT methods.

// ignore: private_collision_in_mixin_application
class OrderedListValue<E> extends ListBase<E> implements LeafValue {
  //with ListMixin<E> {
  final KeyValueStorage<OrderedListTreePath, E> _storage;
  final Uint8List _instanceId;
  int _incrementalTime = 0;
  final OrderedListTreePath _root = new OrderedListTreePath.root();
  final StreamController<OrderedListChange<E>> _changeController =
      new StreamController<OrderedListChange<E>>.broadcast();
  final MapToKVListConverter _converter;
  final bool Function(E, E) _equals;

  /// Default constructor.
  OrderedListValue(this._instanceId, {bool equals(E element1, E element2)})
      : _converter = new MapToKVListConverter<OrderedListTreePath, E>(
            keyConverter: orderedListTreePathConverter),
        _storage = new KeyValueStorage<OrderedListTreePath, E>(),
        _equals = equals ?? ((E element1, E element2) => element1 == element2);

  @override
  Stream<OrderedListChange<E>> get onChange => _changeController.stream;

  @override
  void insert(int index, E element) {
    final sortedKeys = _sortedKeysList();
    if (index < 0 || index > sortedKeys.length) {
      throw new RangeError.value(index, 'index', 'Index is out of range.');
    }

    OrderedListTreePath newKey;
    if (sortedKeys.isEmpty) {
      newKey = _root.getChild(ChildType.value, _instanceId, _timestamp);
    } else {
      bool becomeRightChild = (index != 0 &&
          (index == sortedKeys.length ||
              !sortedKeys[index].isDescendant(sortedKeys[index - 1])));

      if (becomeRightChild) {
        newKey = sortedKeys[index - 1]
            .getChild(ChildType.right, _instanceId, _timestamp);
      } else {
        newKey =
            sortedKeys[index].getChild(ChildType.left, _instanceId, _timestamp);
      }
    }
    _storage[newKey] = element;
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    if (index < 0 || index > length) {
      throw new RangeError.value(index, 'index', 'Index is out of range.');
    }
    int insertIndex = index;
    for (final element in iterable) {
      insert(insertIndex++, element);
    }
  }

  @override
  int indexOf(Object element, [int start = 0]) {
    final values = _valuesList();
    for (int i = start; i < values.length; i++) {
      if (_equals(values[i], element)) {
        return i;
      }
    }
    return -1;
  }

  @override
  int lastIndexOf(Object element, [int start]) {
    final values = _valuesList();
    start ??= values.length - 1;
    for (int i = start; i >= 0; i--) {
      if (_equals(values[i], element)) {
        return i;
      }
    }
    return -1;
  }

  @override
  E removeAt(int index) {
    return _storage.remove(_sortedKeysList()[index]);
  }

  @override
  bool remove(Object element) {
    final keys = _sortedKeysList();
    final values = _valuesList();
    for (int i = 0; i < values.length; i++) {
      if (_equals(values[i], element)) {
        _storage.remove(keys[i]);
        return true;
      }
    }
    return false;
  }

  @override
  E removeLast() => removeAt(length - 1);

  @override
  void removeRange(int start, int end) {
    _sortedKeysList().getRange(start, end).forEach(_storage.remove);
  }

  @override
  void removeWhere(bool test(E element)) {
    final keys = _sortedKeysList();
    final values = _valuesList();
    for (int i = 0; i < values.length; i++) {
      if (test(values[i])) {
        _storage.remove(keys[i]);
      }
    }
  }

  @override
  void replaceRange(int start, int end, Iterable<E> replacement) {
    removeRange(start, end);
    insertAll(start, replacement);
  }

  @override
  void retainWhere(bool test(E element)) {
    removeWhere((element) => !test(element));
  }

  @override
  E operator [](int index) {
    return _valuesList()[index];
  }

  @override
  void operator []=(int index, E element) {
    removeAt(index);
    insert(index, element);
  }

  @override
  int get length => _storage.length;

  @override
  set length(int newLength) {
    // This list is not fixed length.
    // However, it does not support the length setter because [null] cannot be stored.
    throw new UnsupportedError('Length setter is not supported.');
  }

  @override
  void add(E element) {
    insert(length, element);
  }

  @override
  void addAll(Iterable<E> iterable) {
    iterable.forEach(add);
  }

  @override
  void clear() {
    _storage.clear();
  }

  @override
  bool contains(Object element) {
    return indexOf(element) != -1;
  }

  List<OrderedListTreePath> _sortedKeysList() {
    return _storage.keys.toList()..sort();
  }

  List<E> _valuesList() {
    return _sortedKeysList().map((key) => _storage[key]).toList();
  }

  @override
  Change getChange() => _converter.serialize(_storage.getChange());

  @override
  void completeTransaction() {
    _storage.completeTransaction();
  }

  @override
  void applyChange(Change input) {
    final ConvertedChange<OrderedListTreePath, E> change =
        _converter.deserialize(input);
    final keys = _sortedKeysList();
    // We are add deleted keys in case this change is done on our
    // connection. In other cases deletedKeys should be in keys.
    final startKeys = (new SplayTreeSet<OrderedListTreePath>()
          ..addAll(keys)
          ..addAll(change.deletedKeys))
        .toList();

    final deletedPositions = <int>[];
    for (int i = 0; i < startKeys.length; i++) {
      if (change.deletedKeys.contains(startKeys[i])) {
        deletedPositions.add(i);
      }
    }
    _storage.applyChange(change);
    final keysFinal = _sortedKeysList();
    final insertedElements = new SplayTreeMap<int, E>();
    for (int i = 0; i < keysFinal.length; i++) {
      if (change.changedEntries.containsKey(keysFinal[i])) {
        insertedElements[i] = change.changedEntries[keysFinal[i]];
      }
    }
    _changeController
        .add(new OrderedListChange(deletedPositions, insertedElements));
  }

  @override
  void rollbackChange() {
    _storage.rollbackChange();
  }

  @override
  set observer(ValueObserver observer) {
    _storage.observer = observer;
  }

  Uint8List get _timestamp {
    _incrementalTime += 1;
    return new Uint8List(8)..buffer.asByteData().setUint64(0, _incrementalTime);
  }
}
