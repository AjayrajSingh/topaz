// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

/// A [PrefixTree] implementation where the key is a String and the value is
/// a generic
class PrefixTree<T> {
  /// Set the specified key value pair
  void operator []=(String key, T value) {
    _validateKey(key);
    // TODO(meiyili) SO-712
  }

  /// Retrieve the value associated with the key
  T operator [](String key) {
    if (containsKey(key)) {
      Map<String, T> result = search(key);
      return result.values.first;
    } else {
      return null;
    }
  }

  /// Determine if the tree contains the given key
  bool containsKey(String key) {
    _validateKey(key);
    return search(key).isNotEmpty;
  }

  /// Adds a node to the tree if it is absent
  void putIfAbsent(String key, T ifAbsent()) {
    _validateKey(key);

    // TODO(meiyili) SO-712
  }

  /// Remove the key from the tree
  void remove(String key) {
    _validateKey(key);

    // TODO(meiyili) SO-712
  }

  /// Search for nodes matching the prefix, if the prefix is an empty string
  /// it will return all key value pairs
  Map<String, T> search(String prefix) {
    // TODO(meiyili) SO-712
    return new HashMap<String, T>();
  }

  void _validateKey(String key) {
    if (key == null || key.isEmpty) {
      throw new ArgumentError('PrefixTree key cannot be null or empty');
    }
  }
}
