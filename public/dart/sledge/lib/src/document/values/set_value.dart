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

  // TODO: consider Converter as a provider of [equals] and [hashCode] methods.
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
