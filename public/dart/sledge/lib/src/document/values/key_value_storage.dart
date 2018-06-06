// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'converted_change.dart';

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> {
  final Map<K, V> _storage = <K, V>{};
  final ConvertedChange<K, V> _transaction = new ConvertedChange<K, V>();

  /// Value used for nonexisting keys.
  final V defaultValue;

  /// Creates storage.
  KeyValueStorage(this.defaultValue);

  /// Ends transaction and retrieve it's data.
  ConvertedChange<K, V> put() {
    var change = new ConvertedChange.from(_transaction);
    _transaction.clear();
    applyChanges(change);
    return change;
  }

  /// Gets value by key.
  V operator [](K key) {
    if (_transaction.deletedKeys.contains(key)) {
      return defaultValue;
    }
    return _transaction.changedEntries[key] ?? _storage[key] ?? defaultValue;
  }

  /// Sets value for key.
  void operator []=(K key, V value) {
    _transaction.deletedKeys.remove(key);
    _transaction.changedEntries[key] = value;
  }

  /// Applies external transaction.
  void applyChanges(ConvertedChange<K, V> change) {
    _storage.addAll(change.changedEntries);
    change.deletedKeys.forEach(_storage.remove);
  }
}
