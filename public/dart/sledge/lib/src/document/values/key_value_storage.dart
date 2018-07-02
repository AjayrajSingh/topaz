// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'converted_change.dart';

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> extends MapBase<K, V> with MapMixin<K, V> {
  final Map<K, V> _storage;
  // TODO: rename this field.
  final ConvertedChange<K, V> _localChange;
  bool Function(K, K) _equals;
  int Function(K) _hashCode;
  int _length = 0;
  int _localLength = 0;

  /// Creates a storage using the provided [equals] as equality.
  KeyValueStorage({bool equals(K key1, K key2), int hashCode(K key)})
      : _equals = equals,
        _hashCode = hashCode,
        _storage = new HashMap<K, V>(equals: equals, hashCode: hashCode),
        _localChange = new ConvertedChange(
            new HashMap<K, V>(equals: equals, hashCode: hashCode),
            new HashSet<K>(equals: equals, hashCode: hashCode));

  @override
  V operator [](Object key) {
    if (_localChange.deletedKeys.contains(key)) {
      return null;
    }
    return _localChange.changedEntries[key] ?? _storage[key];
  }

  @override
  void operator []=(K key, V value) {
    if (this[key] == null) {
      _localLength += 1;
    }
    _localChange.deletedKeys.remove(key);
    _localChange.changedEntries[key] = value;
  }

  @override
  V remove(Object key) {
    V result = this[key];
    if (result != null) {
      _localLength -= 1;
    }
    _localChange.deletedKeys.add(key);
    _localChange.changedEntries.remove(key);
    return result;
  }

  @override
  void clear() {
    _localChange.changedEntries.clear();
    _localLength = 0;
    _localChange.deletedKeys.addAll(_storage.keys);
  }

  // TODO: return lazy iterable
  @override
  Set<K> get keys {
    return new HashSet<K>(equals: _equals, hashCode: _hashCode)
      ..addAll(_storage.keys)
      ..addAll(_localChange.changedEntries.keys)
      ..removeAll(_localChange.deletedKeys);
  }

  @override
  int get length => _localLength;

  /// Ends transaction and retrieve it's data.
  ConvertedChange<K, V> getChange() {
    var change = new ConvertedChange.from(_localChange);
    _length = _localLength;
    _localChange.clear();
    applyChange(change);
    return change;
  }

  /// Applies external transaction.
  void applyChange(ConvertedChange<K, V> change) {
    _storage.addAll(change.changedEntries);
    change.deletedKeys.forEach(_storage.remove);
  }

  /// Rollbacks current transaction.
  void rollback() {
    _localLength = _length;
    _localChange.clear();
  }
}
