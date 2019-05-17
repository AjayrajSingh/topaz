// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import 'map_api_tester.dart';

void main() {
  setupLogger();

  group('Map API coverage', () {
    MapApiTester<MapValue>(() => MapValue<int, int>())
      ..testApi()
      ..testObserver();
  });

  test('MapValue get and set.', () {
    var m = MapValue<int, int>();
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
    var m = MapValue<int, int>();
    expect(m[0], equals(null));
    m[0] = 3;
    expect(m[0], equals(3));
    m.remove(0);
    expect(m[0], equals(null));
    m.getChange();
    expect(m[0], equals(null));
    m[0] = 2;
    expect(m[0], equals(2));
    m.remove(0);
    expect(m[0], equals(null));
    m[0] = 1;
    expect(m[0], equals(1));
    m.getChange();
    expect(m[0], equals(1));
  });
}
