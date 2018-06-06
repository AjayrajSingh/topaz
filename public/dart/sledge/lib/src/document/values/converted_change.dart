// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Change in inner represention of Sledge data types.
class ConvertedChange<K, V> {
  /// Collection of key value pairs to be set.
  final Map<K, V> changedEntries;

  /// Collection of keys to be deleted.
  final Set<K> deletedKeys;

  /// Constructor.
  ConvertedChange([changedEntries, deletedKeys])
      : changedEntries = changedEntries ?? <K, V>{},
        deletedKeys = deletedKeys ?? new Set<K>();

  /// Copy constructor.
  ConvertedChange.from(ConvertedChange<K, V> change)
      : changedEntries = new Map.from(change.changedEntries),
        deletedKeys = new Set.from(change.deletedKeys);

  /// Clears all changes.
  void clear() {
    changedEntries.clear();
    deletedKeys.clear();
  }
}
