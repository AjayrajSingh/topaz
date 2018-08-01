// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../utils_hash.dart';
import '../uint8list_ops.dart';
import 'key_value.dart';

// Instead of storing (key, value) pair in Ledger we do modification:
// We store ({hash_of_key}, {|key|}{key}{value}).
// [key] is an Uint64 and takes 8 bytes to store.

/// Class to compress long keys.
class Compressor {
  static const _listEquality = const ListEquality();
  static final _mapFactory = new Uint8ListMapFactory<Uint8List>();
  final Map<Uint8List, Uint8List> _keyByHash = _mapFactory.newMap();

  /// Compress Key
  Uint8List compressKey(Uint8List key) {
    return _getAndSaveHashOfKey(key);
  }

  /// Compress KeyValue
  KeyValue compressKeyInEntry(KeyValue entry) {
    Uint8List newKey = compressKey(entry.key);
    Uint8List newValue = concatListOfUint8Lists([
      new Uint8List(8)..buffer.asByteData().setUint64(0, entry.key.length),
      entry.key,
      entry.value
    ]);
    return new KeyValue(newKey, newValue);
  }

  /// Uncompress key.
  Uint8List uncompressKey(Uint8List key) {
    if (!_keyByHash.containsKey(key)) {
      throw new FormatException(
          "Deleting hashed key that didn't appear earlier.");
    }
    return _keyByHash[key];
  }

  /// Uncompress KeyValue.
  KeyValue uncompressKeyInEntry(KeyValue entry) {
    if (entry.value.length < 8) {
      throw new FormatException('Serialized value in a hashed key mode'
          'has length less than eight.');
    }
    final keyLength = entry.value.buffer.asByteData().getUint64(0);
    final content = getUint8ListSuffix(entry.value, 8);
    if (content.length < keyLength) {
      throw new FormatException('Serialized value incorrect format:'
          'key length is larger than real length of content');
    }
    final result = new KeyValue(getUint8ListPrefix(content, keyLength),
        getUint8ListSuffix(content, keyLength));
    // Important side effect: result.key is added to _keyByHash.
    final hash = _getAndSaveHashOfKey(result.key);
    if (!_listEquality.equals(hash, entry.key)) {
      throw new FormatException(
          'Hash of parsed key is not equal to passed hash.');
    }
    return result;
  }

  /// Returns hash of key, and adds (hash, key) pair to caching map.
  Uint8List _getAndSaveHashOfKey(Uint8List key) {
    // TODO: consider using more efficient hash function.
    Uint8List result = hash(key);
    if (_keyByHash.containsKey(key)) {
      if (_keyByHash[key] != result) {
        throw new FormatException('Collision appears.');
      }
    } else {
      _keyByHash[result] = key;
    }
    return result;
  }
}
