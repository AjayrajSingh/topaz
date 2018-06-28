// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import '../dummies/dummy_value_observer.dart';
import 'set_api_tester.dart';

class TestSetValue<E> extends SetValue<E> {
  TestSetValue() : super() {
    observer = new DummyValueObserver();
  }
}

void main() {
  group('Set API coverage', () {
    final tester =
        new SetApiTester<TestSetValue>(() => new TestSetValue<int>());
    // ignore: cascade_invocations
    tester.testApi();
  });

  test('SetValue add and contains.', () {
    var s = new TestSetValue<int>();
    expect(s.contains(0), equals(false));
    expect(s.add(0), equals(true));
    expect(s.contains(0), equals(true));
  });

  test('SetValue add twice and contains.', () {
    var s = new TestSetValue<int>();
    expect(s.contains(0), equals(false));
    expect(s.add(0), equals(true));
    expect(s.add(0), equals(false));
    expect(s.contains(0), equals(true));
  });

  test('SetValue remove.', () {
    var s = new TestSetValue<int>();
    expect(s.remove(2), equals(false));
    expect(s.add(2), equals(true));
    expect(s.remove(2), equals(true));
    expect(s.remove(2), equals(false));
    expect(s.add(2), equals(true));
  });

  test('SetValue add, put, contains, remove.', () {
    var s = new TestSetValue<String>();
    expect(s.contains('-'), equals(false));
    expect(s.add('-'), equals(true));
    expect(s.add('-'), equals(false));
    s.getChange();
    expect(s.add('-'), equals(false));
    expect(s.remove('-'), equals(true));
    expect(s.remove('-'), equals(false));
    s.getChange();
    expect(s.remove('-'), equals(false));
    expect(s.add('-'), equals(true));
    expect(s.add('-'), equals(false));
  });
}
