// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'converted_change.dart';

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> extends MapBase<K, V> with MapMixin<K, V> {
  final Map<K, V> _storage;
  // TODO: rename this field.
  final ConvertedChange<K, V> _transaction;
  bool Function(K, K) _equals;
  int Function(K) _hashCode;

  /// Creates a storage using the provided [equals] as equality.
  KeyValueStorage({bool equals(K key1, K key2), int hashCode(K key)})
      : _equals = equals,
        _hashCode = hashCode,
        _storage = new HashMap<K, V>(equals: equals, hashCode: hashCode),
        _transaction = new ConvertedChange(
            new HashMap<K, V>(equals: equals, hashCode: hashCode),
            new HashSet<K>(equals: equals, hashCode: hashCode));

  @override
  V operator [](Object key) {
    if (_transaction.deletedKeys.contains(key)) {
      return null;
    }
    return _transaction.changedEntries[key] ?? _storage[key];
  }

  @override
  void operator []=(K key, V value) {
    _transaction.deletedKeys.remove(key);
    _transaction.changedEntries[key] = value;
  }

  @override
  V remove(Object key) {
    V result = this[key];
    _transaction.deletedKeys.add(key);
    _transaction.changedEntries.remove(key);
    return result;
  }

  @override
  void clear() {
    _transaction.changedEntries.clear();
    _transaction.deletedKeys.addAll(_storage.keys);
  }

  // TODO: return lazy iterable
  @override
  Set<K> get keys {
    return new HashSet<K>(equals: _equals, hashCode: _hashCode)
      ..addAll(_storage.keys)
      ..addAll(_transaction.changedEntries.keys)
      ..removeAll(_transaction.deletedKeys);
  }

  /// Ends transaction and retrieve it's data.
  ConvertedChange<K, V> getChange() {
    var change = new ConvertedChange.from(_transaction);
    _transaction.clear();
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
    _transaction.clear();
  }
}
