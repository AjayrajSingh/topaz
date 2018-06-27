// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'converted_change.dart';

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> {
  final Map<K, V> _storage;
  final ConvertedChange<K, V> _transaction;

  /// Value used for nonexisting keys.
  final V defaultValue;

  /// Creates a storage using the provided [equals] as equality.
  KeyValueStorage(this.defaultValue,
      {bool equals(K key1, K key2), int hashCode(K key)})
      : _storage = new HashMap<K, V>(equals: equals, hashCode: hashCode),
        _transaction = new ConvertedChange(
            new HashMap<K, V>(equals: equals, hashCode: hashCode),
            new HashSet<K>(equals: equals, hashCode: hashCode));

  /// Ends transaction and retrieve it's data.
  ConvertedChange<K, V> getChange() {
    var change = new ConvertedChange.from(_transaction);
    _transaction.clear();
    applyChange(change);
    return change;
  }

  /// Returns the value for the given [key] or defaultValue if [key] is not in
  /// the storage.
  V operator [](K key) {
    if (_transaction.deletedKeys.contains(key)) {
      return defaultValue;
    }
    return _transaction.changedEntries[key] ?? _storage[key] ?? defaultValue;
  }

  /// Associates the [key] with the given [value].
  void operator []=(K key, V value) {
    _transaction.deletedKeys.remove(key);
    _transaction.changedEntries[key] = value;
  }

  /// Removes [key] and its associated value, if present, from the storage.
  V remove(K key) {
    V result = this[key];
    _transaction.deletedKeys.add(key);
    _transaction.changedEntries.remove(key);
    return result;
  }

  /// Applies external transaction.
  void applyChange(ConvertedChange<K, V> change) {
    _storage.addAll(change.changedEntries);
    change.deletedKeys.forEach(_storage.remove);
  }
}
