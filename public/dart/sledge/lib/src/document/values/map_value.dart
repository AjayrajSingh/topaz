// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import '../base_value.dart';
import '../change.dart';
import '../value_observer.dart';
import 'converted_change.dart';
import 'converter.dart';
import 'key_value_storage.dart';

/// Sledge Value to store Map.
class MapValue<K, V> extends MapBase<K, V>
    with MapMixin<K, V>
    implements BaseValue<MapChange<K, V>> {
  final KeyValueStorage<K, V> _map;
  final StreamController<MapChange<K, V>> _changeController =
      new StreamController<MapChange<K, V>>.broadcast();
  final DataConverter _converter;
  @override
  ValueObserver observer;

  /// Creates a MapValue with provided [equals] as equality.
  MapValue({bool equals(K key1, K key2), int hashCode(K key)})
      : _converter = new DataConverter<K, V>(),
        _map = new KeyValueStorage<K, V>(equals: equals, hashCode: hashCode);

  @override
  Change getChange() => _converter.serialize(_map.getChange());

  @override
  void applyChange(Change input) {
    final change = _converter.deserialize(input);
    _map.applyChange(change);
    _changeController.add(new MapChange<K, V>(change));
  }

  /// Associates the [key] with the given [value].
  @override
  void operator []=(K key, V value) {
    _map[key] = value;
    observer.valueWasChanged();
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
    observer.valueWasChanged();
    return result;
  }

  @override
  void clear() {
    _map.clear();
  }

  @override
  Iterable<K> get keys => _map.keys;

  @override
  Stream<MapChange<K, V>> get onChange => _changeController.stream;
}

/// Sledge Value to store Set.
class SetValue<E> extends SetBase<E>
    with SetMixin<E>
    implements BaseValue<SetChange<E>> {
  final KeyValueStorage<E, bool> _map;
  final DataConverter _converter;
  final StreamController<SetChange<E>> _changeController =
      new StreamController<SetChange<E>>.broadcast();
  @override
  ValueObserver observer;

  // TODO: consider Converter as a provider of |equals| and |hashCode| methods.
  /// Creates a SetValue with provided [equals] as equality.
  /// It should be coherent with encoding of [E] done by Converter.
  SetValue({bool equals(E entry1, E enrtry2), int hashCode(E entry)})
      : _map = new KeyValueStorage<E, bool>(equals: equals, hashCode: hashCode),
        _converter = new DataConverter<E, bool>();

  @override
  Change getChange() => _converter.serialize(_map.getChange());

  @override
  void applyChange(Change input) {
    final change = _converter.deserialize(input);
    _map.applyChange(change);
    _changeController.add(new SetChange<E>(change));
  }

  /// Returns true if [value] is in the set.
  @override
  bool contains(Object value) => _map.containsKey(value);

  /// Adds [value] to the set.
  /// Returns true if [value] was not yet in the set. Otherwise returns
  /// false and the set is not changed.
  @override
  bool add(Object value) {
    final result = !contains(value);
    _map[value] = true;
    observer.valueWasChanged();
    return result;
  }

  @override
  Set<E> toSet() => _map.keys;

  // TODO: write more efficient method.
  @override
  E lookup(Object object) {
    for (final key in toSet()) {
      if (key == object) {
        return key;
      }
    }
    return null;
  }

  @override
  int get length => toSet().length;

  /// Removes [value] from the set. Returns true if [value] was in the set.
  /// Returns false otherwise. The method has no effect if [value] was not in
  /// the set.
  @override
  bool remove(Object value) {
    final result = _map.remove(value) == true;
    observer.valueWasChanged();
    return result;
  }

  @override
  Iterator<E> get iterator => toSet().iterator;

  @override
  Stream<SetChange<E>> get onChange => _changeController.stream;
}
