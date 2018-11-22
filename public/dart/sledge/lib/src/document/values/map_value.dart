// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import '../change.dart';
import '../leaf_value.dart';
import '../value_observer.dart';
import 'converted_change.dart';
import 'converter.dart';
import 'key_value_storage.dart';

/// Sledge Value to store Map.
class MapValue<K, V> extends MapBase<K, V>
    with MapMixin<K, V>
    implements LeafValue {
  final KeyValueStorage<K, V> _map;
  final StreamController<MapChange<K, V>> _changeController =
      new StreamController<MapChange<K, V>>.broadcast();
  final MapToKVListConverter _converter;

  /// Creates a MapValue with provided [equals] as equality.
  MapValue({bool equals(K key1, K key2), int hashCode(K key)})
      : _converter = new MapToKVListConverter<K, V>(),
        _map = new KeyValueStorage<K, V>(equals: equals, hashCode: hashCode);

  @override
  Change getChange() => _converter.serialize(_map.getChange());

  @override
  void completeTransaction() {
    _map.completeTransaction();
  }

  @override
  void applyChange(Change input) {
    final change = _converter.deserialize(input);
    _map.applyChange(change);
    _changeController.add(new MapChange<K, V>(change));
  }

  @override
  void rollbackChange() {
    _map.rollbackChange();
  }

  @override
  Stream<MapChange<K, V>> get onChange => _changeController.stream;

  @override
  set observer(ValueObserver observer) {
    _map.observer = observer;
  }

  /// Associates the [key] with the given [value].
  @override
  void operator []=(K key, V value) {
    _map[key] = value;
  }

  /// Returns the value for the given [key] or null if [key] is not in the map.
  @override
  V operator [](Object key) => _map[key];

  /// Removes [key] and its associated value, if presented, from the map.
  /// Returns the value associated with [key] before it was removed. Returns
  /// null it [key] was not in the map.
  @override
  V remove(Object key) {
    final result = _map.remove(key);
    return result;
  }

  @override
  void clear() {
    _map.clear();
  }

  @override
  Iterable<K> get keys => _map.keys;

  @override
  int get length => _map.length;
}
