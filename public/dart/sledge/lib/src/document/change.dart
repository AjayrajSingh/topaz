// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'uint8list_ops.dart';
import 'values/key_value.dart';

/// Change from one or more commits.
class Change {
  /// List of changed key value pairs.
  final List<KeyValue> changedEntries;

  /// List of deleted keys.
  final List<Uint8List> deletedKeys;

  /// Constructor.
  Change([List<KeyValue> changedEntries, List<Uint8List> deletedKeys])
      : changedEntries = changedEntries ?? <KeyValue>[],
        deletedKeys = deletedKeys ?? <Uint8List>[];

  /// Adds all changes and deletions to this.
  void addAll(final Change other) {
    changedEntries.addAll(other.changedEntries);
    deletedKeys.addAll(other.deletedKeys);
  }

  /// Returns a new Change with prefix attached to all entries.
  Change withPrefix(Uint8List prefix) {
    Change result = new Change();
    for (final change in changedEntries) {
      result.changedEntries.add(
          new KeyValue(concatUint8Lists(prefix, change.key), change.value));
    }
    for (final key in deletedKeys) {
      result.deletedKeys.add(concatUint8Lists(prefix, key));
    }
    return result;
  }

  /// Splits all changes by prefixes.
  Map<Uint8List, Change> splitByPrefix(int prefixLen) {
    final splittedChanges = newUint8ListMap<Change>();
    for (final change in changedEntries) {
      final prefix = getUint8ListPrefix(change.key, prefixLen);
      final newChange = splittedChanges.putIfAbsent(prefix, () => new Change());
      newChange.changedEntries.add(new KeyValue(
          getUint8ListSuffix(change.key, prefixLen), change.value));
    }
    for (final deletion in deletedKeys) {
      final prefix = getUint8ListPrefix(deletion, prefixLen);
      final newChange = splittedChanges.putIfAbsent(prefix, () => new Change());
      newChange.deletedKeys.add(getUint8ListSuffix(deletion, prefixLen));
    }
    return splittedChanges;
  }

  /// Clear change.
  void clear() {
    changedEntries.clear();
    deletedKeys.clear();
  }
}
