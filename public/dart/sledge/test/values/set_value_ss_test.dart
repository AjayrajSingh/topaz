// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports, avoid_catches_without_on_clauses

import 'package:fuchsia_logger/logger.dart';
import 'package:sledge/src/document/values/set_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';

// Wraps construction of Fleet of SetValues.
class SetFleetFactory<E> {
  const SetFleetFactory();

  // Returns Fleet of [count] SetValues.
  Fleet<SetValue<E>> newFleet(int count) {
    return Fleet<SetValue<E>>(count, (index) => SetValue<E>());
  }
}

const SetFleetFactory<int> intSetFleetFactory = SetFleetFactory<int>();

void main() async {
  setupLogger();

  test('Test with framework', () async {
    final fleet = intSetFleetFactory.newFleet(2)
      ..runInTransaction(0, (SetValue<int> s) async {
        s..add(1)..add(2);
      })
      ..synchronize([0, 1])
      ..runInTransaction(1, (SetValue<int> s) async {
        expect(s, unorderedEquals([1, 2]));
        s
          ..remove(1)
          ..add(3);
      })
      ..synchronize([0, 1])
      ..runInTransaction(0, (SetValue<int> s) async {
        expect(s, unorderedEquals([2, 3]));
      });
    await fleet.testSingleOrder();
  });
}
