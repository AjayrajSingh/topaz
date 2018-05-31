// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> {
  final Map<K, V> _storage = <K, V>{};
  final Map<K, V> _transaction = <K, V>{};

  /// Value used for nonexisting keys.
  final V defaultValue;

  /// Creates storage.
  KeyValueStorage(this.defaultValue);

  /// Ends transaction and retrieve it's data.
  Map<K, V> put() {
    var change = Map.from(_transaction);
    _storage.addAll(_transaction);
    _transaction.clear();
    return change;
  }

  /// Gets value by key.
  V operator [](K key) {
    return _transaction[key] ?? _storage[key] ?? defaultValue;
  }

  /// Sets value for key.
  void operator []=(K key, V value) {
    _transaction[key] = value;
  }

  /// Returns all the keys.
  Iterable<K> get keys {
    return _storage.keys;
  }

  /// Applies external transaction.
  void applyChanges(Map<K, V> change) {
    _storage.addAll(change);
  }
}
