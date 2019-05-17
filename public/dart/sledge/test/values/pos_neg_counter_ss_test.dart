// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'dart:typed_data';

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/pos_neg_counter_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';
import '../crdt_test_framework/storage_state.dart';

class PosNegCounterFleetFactory<T extends num> {
  const PosNegCounterFleetFactory();

  Fleet<PosNegCounterValue<T>> newFleet(int count) {
    return Fleet<PosNegCounterValue<T>>(count,
        (index) => PosNegCounterValue<T>(Uint8List.fromList([index])));
  }
}

const PosNegCounterFleetFactory<int> integerCounterFleetFactory =
    PosNegCounterFleetFactory<int>();

void main() async {
  setupLogger();

  test('PosNegCounterValue with StorageState', () {
    var cnt1 = PosNegCounterValue<int>(Uint8List.fromList([1])),
        cnt2 = PosNegCounterValue<int>(Uint8List.fromList([2])),
        cnt3 = PosNegCounterValue<int>(Uint8List.fromList([3]));
    var ss1 = StorageState(),
        ss2 = StorageState(),
        ss3 = StorageState();
    cnt1.add(4);
    cnt2.add(2);
    ss1.applyChange(cnt1.getChange(), 1);
    ss2.applyChange(cnt2.getChange(), 2);
    cnt2.applyChange(ss2.updateWith(ss1));
    expect(cnt1.value, equals(4));
    expect(cnt2.value, equals(6));
    cnt1.applyChange(ss1.updateWith(ss2));
    expect(cnt2.value, equals(6));
    cnt3.applyChange(ss3.updateWith(ss2));
    expect(cnt3.value, equals(6));
  });

  test('PosNegCounter with framework. Single run.', () async {
    final fleet = integerCounterFleetFactory.newFleet(2)
      ..runInTransaction(0, (PosNegCounterValue<int> cnt0) async {
        cnt0.add(1);
      })
      ..runInTransaction(1, (PosNegCounterValue<int> cnt1) async {
        cnt1.add(2);
      })
      ..synchronize([0, 1])
      ..runInTransaction(0, (PosNegCounterValue<int> cnt0) async {
        expect(cnt0.value, equals(3));
      });
    await fleet.testSingleOrder();
  });

  test('PosNegCounter with framework', () async {
    final fleet = integerCounterFleetFactory.newFleet(3)
      ..runInTransaction(0, (PosNegCounterValue<int> cnt0) async {
        cnt0.add(1);
      })
      ..runInTransaction(1, (PosNegCounterValue<int> cnt1) async {
        cnt1.add(2);
      })
      ..synchronize([0, 1])
      ..runInTransaction(0, (PosNegCounterValue<int> cnt0) async {
        expect(cnt0.value, equals(3));
      })
      ..runInTransaction(2, (PosNegCounterValue<int> cnt2) async {
        cnt2.add(-5);
      })
      ..synchronize([0, 2])
      ..runInTransaction(2, (PosNegCounterValue<int> cnt2) async {
        expect(cnt2.value, equals(-2));
      })
      ..runInTransaction(1, (PosNegCounterValue<int> cnt2) async {
        expect(cnt2.value, equals(3));
      });
    await fleet.testAllOrders();
  });
}
