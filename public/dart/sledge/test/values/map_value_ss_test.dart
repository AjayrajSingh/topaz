// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports, avoid_catches_without_on_clauses

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';

// Wraps construction of Fleet of MapValues.
class MapFleetFactory<K, V> {
  const MapFleetFactory();

  // Returns Fleet of [count] MapValues.
  Fleet<MapValue<K, V>> newFleet(int count) {
    return Fleet<MapValue<K, V>>(count, (index) => MapValue<K, V>());
  }
}

const MapFleetFactory<int, int> intMapFleetFactory =
    MapFleetFactory<int, int>();

void main() async {
  setupLogger();

  test('Test with framework', () async {
    final fleet = intMapFleetFactory.newFleet(2)
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[1] = 2;
      })
      ..runInTransaction(1, (MapValue<int, int> m1) async {
        m1[1] = 4;
        m1[2] = 2;
      })
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        m0[2] = 4;
      })
      ..synchronize([0, 1])
      ..runInTransaction(0, (MapValue<int, int> m0) async {
        expect(m0[1], equals(4));
        expect(m0[2], equals(4));
      });
    // TODO: enable manual node names, and replace names here
    await fleet.testFixedOrder(
        ['n-init', 'm-0-n1', 'm-1-n2', 'm-0-n3', 's-0_1-n4', 'm-0-n5']);
  });
}
