// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:typed_data';

import 'package:collection/collection.dart';

/// Concatenate two byte arrays.
Uint8List concatUint8Lists(Uint8List a, Uint8List b) {
  return new Uint8List(a.length + b.length)..setAll(0, a)..setAll(a.length, b);
}

/// Concatenate list of byte arrays.
Uint8List concatListOfUint8Lists(List<Uint8List> list) {
  int sumLength = 0;
  for (final x in list) {
    sumLength += x.length;
  }
  final result = new Uint8List(sumLength);
  int pos = 0;
  for (final x in list) {
    result.setAll(pos, x);
    pos += x.length;
  }
  return result;
}

/// Returns the prefix of [x] of length [prefixLen].
Uint8List getUint8ListPrefix(Uint8List x, int prefixLen) {
  return new Uint8List(prefixLen)..setAll(0, x.getRange(0, prefixLen));
}

/// Returns the suffix of [x] starting from [prefixLen].
Uint8List getUint8ListSuffix(Uint8List x, int prefixLen) {
  return new Uint8List(x.length - prefixLen)
    ..setAll(0, x.getRange(prefixLen, x.length));
}

/// HashMap with Uint8Lists as a keys, and content equality comparator.
class Uint8ListMapFactory<T> {
  static const _listEquality = const ListEquality<int>();

  /// Returns Map.
  HashMap<Uint8List, T> newMap() {
    return new HashMap<Uint8List, T>(
        equals: _listEquality.equals, hashCode: _listEquality.hash);
  }
}
