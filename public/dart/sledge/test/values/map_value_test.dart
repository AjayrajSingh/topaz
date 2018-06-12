// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:async';

import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';

class TestMapValue<K, V> extends MapValue<K, V> {
  TestMapValue() : super() {
    this.observer = new DummyValueObserver();
  }
}

void main() {
  test('MapValue get and set.', () {
    var m = new TestMapValue<int, int>();
    expect(m[0], equals(null));
    expect(m[3], equals(null));
    m[2] = 1;
    m[0] = 3;
    expect(m[2], equals(1));
    expect(m[0], equals(3));
    m[0] = 1;
    expect(m[1], equals(null));
    expect(m[0], equals(1));
  });

  test('MapValue get, set and remove.', () {
    var m = new TestMapValue<int, int>();
    expect(m[0], equals(null));
    m[0] = 3;
    expect(m[0], equals(3));
    m.remove(0);
    expect(m[0], equals(null));
    m.put();
    expect(m[0], equals(null));
    m[0] = 2;
    expect(m[0], equals(2));
    m.remove(0);
    expect(m[0], equals(null));
    m[0] = 1;
    expect(m[0], equals(1));
    m.put();
    expect(m[0], equals(1));
  });
}
