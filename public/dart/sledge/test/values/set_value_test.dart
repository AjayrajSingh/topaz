// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/set_value.dart';
import 'package:test/test.dart';

import 'set_api_tester.dart';

void main() {
  setupLogger();

  group('Set API coverage', () {
    SetApiTester<SetValue>(() => SetValue<int>())
      ..testApi()
      ..testObserver();
  });

  test('SetValue add and contains.', () {
    var s = SetValue<int>();
    expect(s.contains(0), equals(false));
    expect(s.add(0), equals(true));
    expect(s.contains(0), equals(true));
  });

  test('SetValue add twice and contains.', () {
    var s = SetValue<int>();
    expect(s.contains(0), equals(false));
    expect(s.add(0), equals(true));
    expect(s.add(0), equals(false));
    expect(s.contains(0), equals(true));
  });

  test('SetValue remove.', () {
    var s = SetValue<int>();
    expect(s.remove(2), equals(false));
    expect(s.add(2), equals(true));
    expect(s.remove(2), equals(true));
    expect(s.remove(2), equals(false));
    expect(s.add(2), equals(true));
  });

  test('SetValue add, put, contains, remove.', () {
    var s = SetValue<String>();
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
