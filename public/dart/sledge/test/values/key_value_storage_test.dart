// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/key_value_storage.dart';
import 'package:test/test.dart';

import 'map_api_tester.dart';

void main() {
  setupLogger();

  group('Map API coverage', () {
    MapApiTester<KeyValueStorage>(() => KeyValueStorage<int, int>())
      ..testApi()
      ..testObserver();
  });

  test('getChange', () {
    KeyValueStorage kv = KeyValueStorage<int, int>();
    expect(kv.length, equals(0));
    kv[0] = 2;
    expect(kv[0], equals(2));
    expect(kv.length, equals(1));
    kv.getChange();
    expect(kv[0], equals(2));
    expect(kv.length, equals(1));
  });

  test('getChange + applyChange', () {
    KeyValueStorage kv1 = KeyValueStorage<int, int>(),
        kv2 = KeyValueStorage<int, int>();
    kv1[0] = 2;
    kv2.applyChange(kv1.getChange());
    expect(kv2[0], equals(2));
    expect(kv2.length, equals(1));
  });

  // TODO: add tests to check that all operations continue working as expected with
  // getChange, applyChanges and rollback
}
