// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

// ignore_for_file: implementation_imports
import 'package:sledge/src/document/change.dart';
import 'package:sledge/src/document/uint8list_ops.dart';
import 'package:sledge/src/document/values/key_value.dart';

import 'entry.dart';

final _mapFactory = new Uint8ListMapFactory<Entry>();

/// StorageState is a key-value storage with timestamp per key.
/// It stores timestamps for deleted keys (time of deletion).
/// Used to fake Ledger's KeyValue storage.
class StorageState {
  final Map<Uint8List, Entry> _storage = _mapFactory.newMap();

  /// Applies [change] to storage. Uses [timestamp] as a time of update.
  void applyChange(Change change, int timestamp) {
    for (final entry in change.changedEntries) {
      _storage[entry.key] = new Entry(entry.value, timestamp);
    }
    for (final key in change.deletedKeys) {
      _storage[key] = new Entry.deleted(timestamp);
    }
    // TODO: check that changedEntries and deletedKeys do not intersect.
  }

  /// Updates state of this with respect to [other]. Returns change done to this.
  Change updateWith(StorageState other) {
    final changedEntries = <KeyValue>[];
    final deletedKeys = <Uint8List>[];

    for (final key in other._storage.keys) {
      // Check who have newer value for this key.
      if (!_storage.containsKey(key) ||
          _storage[key].timestamp < other._storage[key].timestamp) {
        // Use other's value for this key.
        _storage[key] = other._storage[key];
        if (other._storage[key].isDeleted) {
          deletedKeys.add(key);
        } else {
          changedEntries.add(new KeyValue(key, other._storage[key].value));
        }
      }
    }
    return new Change(changedEntries, deletedKeys);
  }
}
