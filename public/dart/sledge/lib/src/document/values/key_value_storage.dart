// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import '../value_observer.dart';
import 'converted_change.dart';

/// Sledge DataTypes internal storage.
class KeyValueStorage<K, V> extends MapBase<K, V> with MapMixin<K, V> {
  final Map<K, V> _storage;
  // [_changesToRollback] stores the ConvertedChange that should be applied to
  // roll back the transaction that is in progress. For each key that was
  // affected in this transaction:
  // - it stores the key and the old value in [changedKeys], if key was in [_storage]
  // - it stores the key in [deletedKeys], if key wasn't in [_storage]
  final ConvertedChange<K, V> _changeToRollback;
  ValueObserver _observer;

  /// Creates a storage using the provided [equals] as equality.
  KeyValueStorage({bool equals(K key1, K key2), int hashCode(K key)})
      : _storage = HashMap<K, V>(equals: equals, hashCode: hashCode),
        _changeToRollback = ConvertedChange(
            HashMap<K, V>(equals: equals, hashCode: hashCode),
            HashSet<K>(equals: equals, hashCode: hashCode));

  @override
  V operator [](Object key) => _storage[key];

  @override
  void operator []=(K key, V value) {
    _backupStateOfKeyValue(key);
    _storage[key] = value;
    _valueWasChanged();
  }

  @override
  V remove(Object key) {
    _backupStateOfKeyValue(key);
    V result = this[key];
    _storage.remove(key);
    _valueWasChanged();
    return result;
  }

  @override
  void clear() {
    _storage.keys.forEach(_backupStateOfKeyValue);
    _storage.clear();
    _valueWasChanged();
  }

  @override
  Iterable<K> get keys => _storage.keys;

  @override
  int get length => _storage.length;

  /// Retrieves the current transaction's data.
  ConvertedChange<K, V> getChange() {
    final change = ConvertedChange<K, V>();
    // [_changeToRollback.deletedKeys] is a collection of keys that were not in
    // [_storage] when the transaction started, but were affected by this
    // transaction.
    for (final key in _changeToRollback.deletedKeys) {
      // When we add a key-value pair in a transaction, we add the corresponding
      // key in [_changeToRollback.deletedKeys]. It is valid however, to remove
      // that key in the same transaction. In that case, [deletedKeys] will not
      // be updated (to remove the key), and _storage will not contain the given
      // value. We thus need to check whether the key exists, and only add it in
      // the list of [change.changedEntries] if it does.
      if (_storage.containsKey(key)) {
        change.changedEntries[key] = _storage[key];
      }
    }
    // [_changeToRollback.changedEntries] is a collection of keys that were in
    // [_storage] when transaction started and were affected by this transaction.
    for (final key in _changeToRollback.changedEntries.keys) {
      final newValue = _storage[key];
      if (newValue != null) {
        change.changedEntries[key] = newValue;
      } else {
        change.deletedKeys.add(key);
      }
    }
    return change;
  }

  /// Completes the current transaction and starts the next one.
  void completeTransaction() {
    _changeToRollback.clear();
  }

  /// Applies external transaction.
  void applyChange(ConvertedChange<K, V> change) {
    _storage.addAll(change.changedEntries);
    change.deletedKeys.forEach(_storage.remove);
  }

  /// Rolls back all local modifications.
  void rollbackChange() {
    applyChange(_changeToRollback);
    _changeToRollback.clear();
  }

  /// Sets the observer.
  set observer(ValueObserver observer) {
    _observer = observer;
  }

  /// Backs up info for [key] to enable rollback on it.
  void _backupStateOfKeyValue(K key) {
    if (_changeToRollback.deletedKeys.contains(key) ||
        _changeToRollback.changedEntries.containsKey(key)) {
      return;
    }
    final previousValue = this[key];
    if (previousValue == null) {
      _changeToRollback.deletedKeys.add(key);
    } else {
      _changeToRollback.changedEntries[key] = previousValue;
    }
  }

  void _valueWasChanged() {
    _observer?.valueWasChanged();
  }
}
