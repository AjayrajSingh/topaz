// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports, avoid_catches_without_on_clauses

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/src/document/values/map_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';

// Wraps construction of Fleet of OrderedListValues.
class MapFleetFactory<K, V> {
  const MapFleetFactory();

  // Returns Fleet of [count] MapValues.
  Fleet<MapValue<K, V>> newFleet(int count) {
    return new Fleet<MapValue<K, V>>(count, (index) => new MapValue<K, V>());
  }
}

const MapFleetFactory<int, int> intMapFleetFactory =
    const MapFleetFactory<int, int>();

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
        ['init', 'm0_n1', 'm1_n2', 'm0_n3', 's0_1_n4', 'm0_n5']);
  });
}
