// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Jenkins hash function, optimized for small integers.
//
// Borrowed from the dart sdk: sdk/lib/math/jenkins_smi_hash.dart.
class _Jenkins {
  static int combine(final int h, Object o) {
    assert(o is! Iterable);
    int hash = h;
    hash = 0x1fffffff & (hash + o.hashCode);
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(final int h) {
    int hash = h;
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Combine the [Object.hashCode] values of an arbitrary number of objects from
/// an [Iterable] into one value. This function will return the same value if
/// given null as if given an empty list.
int deepHash(Iterable<Object> arguments) {
  int result = 0;
  if (arguments != null) {
    for (Object argument in arguments) {
      if (argument is Iterable) {
        argument = deepHash(argument);
      }
      result = _Jenkins.combine(result, argument);
    }
  }
  return _Jenkins.finish(result);
}

/// Deep equality helper function for Iterables.
bool deepEquals(Iterable<Object> a, Iterable<Object> b) {
  if (a.length != b.length) {
    return false;
  }
  final ai = a.iterator;
  final bi = b.iterator;
  while (ai.moveNext() && bi.moveNext()) {
    if (ai.current is Iterable) {
      if (bi.current is Iterable) {
        if (!deepEquals(ai.current, bi.current)) {
          return false;
        }
      } else {
        return false;
      }
    } else {
      if (ai.current != bi.current) {
        return false;
      }
    }
  }
  return true;
}
