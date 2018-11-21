// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:collection/collection.dart';

import '../../sledge_errors.dart';
import '../../uint8list_ops.dart';
import 'key_value.dart';

/// Class to compress long keys.
///
/// Instead of directly storing (key, value) pairs in Ledger, we store
/// ({hash(key)}, {|key|}{key}{value}).
/// {|key|} is an Uint64 and takes 8 bytes to store.
class Compressor {
  static const _listEquality = const ListEquality();
  final Map<Uint8List, Uint8List> _keyByHash = newUint8ListMap<Uint8List>();

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
  Uint8List uncompressKey(Uint8List keyHash) {
    final key = _keyByHash[keyHash];
    if (key == null) {
      throw new InternalSledgeError('Unable to uncompress key `$keyHash`.');
    }
    return key;
  }

  /// Uncompress KeyValue.
  KeyValue uncompressKeyInEntry(KeyValue entry) {
    if (entry.value.length < 8) {
      throw new InternalSledgeError(
          'In a hashed key mode, the value size must be '
          '>= 8. Found ${entry.value.length} instead for entry `$entry`.');
    }
    final keyLength = entry.value.buffer.asByteData().getUint64(0);
    if (entry.value.length < 8 + keyLength) {
      throw new InternalSledgeError(
          'Incorrect format for value of given entry: '
          'The parsed length ($keyLength) is larger than the value content\'s '
          'length (${entry.value.length - 8}). Entry: `$entry`');
    }
    final key = getSublistView(entry.value, start: 8, end: 8 + keyLength);
    final value = getSublistView(entry.value, start: 8 + keyLength);

    // TODO(nellyv): Remove this validation?
    // Important side effect: result.key is added to _keyByHash.
    final hash = _getAndSaveHashOfKey(key);
    if (!_listEquality.equals(hash, entry.key)) {
      throw new InternalSledgeError(
          'Hash of parsed key is not equal to passed hash (expected `$hash`, got `${entry.key}`).');
    }
    return new KeyValue(key, value);
  }

  /// Returns hash of key, and adds (hash, key) pair to caching map.
  Uint8List _getAndSaveHashOfKey(Uint8List key) {
    // TODO: consider using more efficient hash function.
    Uint8List keyHash = hash(key);
    _keyByHash.putIfAbsent(keyHash, () => key);
    return keyHash;
  }
}
