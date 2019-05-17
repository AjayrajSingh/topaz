// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/last_one_wins_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';

// Wraps the construction of Fleet of LastOneWinValues.
class LastOneWinsFleetFactory<T> {
  const LastOneWinsFleetFactory();

  Fleet<LastOneWinsValue<T>> newFleet(int count) {
    return Fleet<LastOneWinsValue<T>>(
        count, (index) => LastOneWinsValue<T>());
  }
}

const LastOneWinsFleetFactory<bool> boolLastOneWinsFleetFactory =
    LastOneWinsFleetFactory<bool>();

class FalseChecker extends Checker<LastOneWinsValue<bool>> {
  @override
  void check(LastOneWinsValue<bool> value) {
    expect(value.value, equals(false));
  }
}

void main() async {
  setupLogger();

  test('Checker passes.', () async {
    final fleet = boolLastOneWinsFleetFactory.newFleet(2)
      ..runInTransaction(0, (LastOneWinsValue<bool> b) async {
        b.value = false;
      })
      ..runInTransaction(1, (LastOneWinsValue<bool> b) async {
        b.value = false;
      })
      ..synchronize([0, 1])
      ..addChecker(() => FalseChecker());
    await fleet.testAllOrders();
  });

  test('Checker fails.', () async {
    final fleet = boolLastOneWinsFleetFactory.newFleet(1)
      ..runInTransaction(0, (LastOneWinsValue<bool> b) async {
        b.value = true;
      })
      ..addChecker(() => FalseChecker());
    expect(fleet.testAllOrders(), throwsA(TypeMatcher<TestFailure>()));
  });
}
