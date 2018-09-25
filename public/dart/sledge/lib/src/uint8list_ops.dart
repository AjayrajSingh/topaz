// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';

// TODO: consider short function names and importing with prefix.

/// Concatenate two byte arrays.
Uint8List concatUint8Lists(Uint8List a, Uint8List b) {
  return new Uint8List(a.length + b.length)..setAll(0, a)..setAll(a.length, b);
}

// TODO: consider using Iterable instead of List.
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

/// Returns a _view_ of a region of [x] starting at [start] (inclusive) and
/// ending at [end] (exclusive).
Uint8List getSublistView(Uint8List x, {int start = 0, int end}) {
  end ??= x.length;
  return new UnmodifiableUint8ListView(
      x.buffer.asUint8List(x.offsetInBytes + start, end - start));
}

/// Returns a Uint8List created from the utf8 encoding of [string].
/// [string] must be non-null.
Uint8List getUint8ListFromString(String string) {
  return new Uint8List.fromList(utf8.encode(string));
}

/// Returns a new HashMap with Uint8Lists as a keys.
/// Note: The type T is enforced only at compile time.
HashMap<Uint8List, T> newUint8ListMap<T>() {
  const listEquality = const ListEquality<int>();
  return new HashMap<Uint8List, T>(
      equals: listEquality.equals, hashCode: listEquality.hash);
}

int _compareLists(List a, List b) {
  final minLength = min(a.length, b.length);
  for (int i = 0; i < minLength; i++) {
    if (a[i] != b[i]) {
      return a[i] - b[i];
    }
  }
  // Missing parts come before present ones.
  return a.length.compareTo(b.length);
}

/// Returns a new ordered HashMap with Uint8Lists as a keys.
/// Note: The type T is enforced only at compile time.
SplayTreeMap<Uint8List, T> newUint8ListOrderedMap<T>() {
  return new SplayTreeMap<Uint8List, T>(_compareLists);
}

/// Returns a 20 bytes long hash of [data].
Uint8List hash(Uint8List data) {
  final iterable = sha256.convert(data).bytes.getRange(0, 20);
  return new Uint8List.fromList(new List.from(iterable));
}

final _random = new Random.secure();

/// Returns a list of random bytes of a given [length].
Uint8List randomUint8List(int length) {
  final result = new Uint8List(length);
  for (int i = 0; i < length; i++) {
    result[i] = _random.nextInt(256);
  }
  return result;
}
