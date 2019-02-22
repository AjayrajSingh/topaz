// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:collection';
import 'dart:math' show Random;
import 'dart:typed_data';

import 'package:lib.app.dart/logging.dart';
import 'package:sledge/src/document/values/converted_change.dart';
import 'package:sledge/src/document/values/ordered_list_value.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/crdt_test_framework.dart';
import 'matchers.dart';

// Wraps construction of Fleet of OrderedListValues.
class OrderedListFleetFactory<T> {
  const OrderedListFleetFactory();

  // Returns Fleet of [count] OrderedListValues with pairwise different
  // instanceIds.
  Fleet<OrderedListValue<T>> newFleet(int count) {
    return new Fleet<OrderedListValue<T>>(count,
        (index) => new OrderedListValue<T>(new Uint8List.fromList([index])));
  }
}

const OrderedListFleetFactory<int> integerOrderedListFleetFactory =
    const OrderedListFleetFactory<int>();

// Checks that relative orders of elements do not change.
// Throws an error if some pair of elements [a] and [b] appear in both orders,
// e.g. ...[a]...[b]... and ...[b]...[a]...
//
// This checker works properly only if there are no insertions of equal
// elements.
class RelativeOrderChecker<T> extends Checker<OrderedListValue<T>> {
  Map<T, Set<T>> graph = <T, Set<T>>{};

  @override
  void check(OrderedListValue<T> orderedList) {
    var list = orderedList.toList();
    for (T a in list) {
      graph.putIfAbsent(a, () => <T>{});
    }
    // Iterate over all the pairs (i,j) contained in [0, list.length), with i<j.
    for (int i = 0; i < list.length; i++) {
      for (int j = i + 1; j < list.length; j++) {
        T a = list[i], b = list[j];
        expect(graph[b].contains(a), isFalse);
        graph[a].add(b);
      }
    }
  }
}

// Inserts [value] into [list] at position [pos]. And checks that this operation
// performed correctly.
void insertIntWithCheck(List<int> list, int pos, int value) {
  final correctList = list.toList();
  list.insert(pos, value);
  correctList.insert(pos, value);
  expect(list, equals(correctList));
}

// Creates fleet of [countInstances] OrderedListValues. Runs test in
// [countEpochs] epochs. Between epochs all instances are synchronized. In one
// epoch on each instance performs [countInsertions] insertions at random
// positions.
//
// For each insertion checks that it was performed correctly. And
// checks that relative order of elements do not change.
Future randomRelativeOrderTest(
    {final int countInstances,
    final int countEpochs,
    final int countInsertions,
    final int seed}) async {
  test(
      'Check relative order '
      '(i: $countInstances, e: $countEpochs, ins: $countInsertions, seed: $seed).',
      () async {
    final random = new Random(seed);
    int incValue = 0;
    final fleet = integerOrderedListFleetFactory.newFleet(countInstances);
    final instanceIdList =
        new List<int>.generate(countInstances, (index) => index);

    for (int epoch = 0; epoch < countEpochs; epoch++) {
      for (int instance = 0; instance < countInstances; instance++) {
        fleet.runInTransaction(instance, (OrderedListValue<int> l) async {
          for (int it = 0; it < countInsertions; it++) {
            int pos = random.nextInt(l.length + 1);
            insertIntWithCheck(l, pos, incValue++);
          }
        });
      }
      fleet.synchronize(instanceIdList);
    }
    fleet.addChecker(() => new RelativeOrderChecker<int>());
    await fleet.testAllOrders();
  });
}

void main() async {
  setupLogger();

  test('OrderedList with framework', () async {
    final fleet = integerOrderedListFleetFactory.newFleet(2)
      ..runInTransaction(0, (OrderedListValue<int> l0) async {
        l0.insert(0, 1);
      })
      ..runInTransaction(1, (OrderedListValue<int> l1) async {
        l1.insert(0, 2);
      })
      ..synchronize([0, 1])
      ..runInTransaction(0, (OrderedListValue<int> l0) async {
        expect(l0.toList(), anyOf(equals([1, 2]), equals([2, 1])));
      });
    await fleet.testAllOrders();
  });

  test('OrderedList with framework. Check relative order.', () async {
    final fleet = integerOrderedListFleetFactory.newFleet(3)
      ..runInTransaction(0, (OrderedListValue<int> l0) async {
        l0..insert(0, 1)..insert(1, 2);
      })
      ..runInTransaction(1, (OrderedListValue<int> l1) async {
        l1..insert(0, 3)..insert(1, 4);
      })
      ..runInTransaction(2, (OrderedListValue<int> l2) async {
        l2..insert(0, 5)..insert(1, 6);
      })
      ..synchronize([0, 1, 2])
      ..addChecker(() => new RelativeOrderChecker<int>());
    await fleet.testAllOrders();
  });

  test('Ordered list. Test deletion.', () async {
    final fleet = integerOrderedListFleetFactory.newFleet(2)
      ..runInTransaction(0, (final cnt) async {
        cnt.insert(0, 0);
      })
      ..runInTransaction(0, (final cnt) async {
        cnt.removeAt(0);
      })
      ..synchronize([0, 1])
      ..runInTransaction(1, (final cnt) async {
        expect(cnt.isEmpty, isTrue);
      });
    await fleet.testSingleOrder();
  });

  test('Ordered list. Stream.', () async {
    final fleet = integerOrderedListFleetFactory.newFleet(3);
    for (int id = 0; id < 3; id++) {
      fleet.runInTransaction(id, (final cnt) async {
        expect(
            cnt.onChange,
            emitsInOrder([
              new OrderedListChangeMatcher(new OrderedListChange<int>(
                  [], new SplayTreeMap<int, int>.fromIterables([0], [1]))),
              new OrderedListChangeMatcher(new OrderedListChange<int>([],
                  new SplayTreeMap<int, int>.fromIterables([0, 2], [2, 3]))),
              new OrderedListChangeMatcher(new OrderedListChange<int>(
                  [1, 2], new SplayTreeMap<int, int>.fromIterables([], []))),
              new OrderedListChangeMatcher(new OrderedListChange<int>(
                  [], new SplayTreeMap<int, int>.fromIterables([0], [5]))),
            ]));
      });
    }
    fleet
      ..runInTransaction(0, (final cnt) async {
        cnt.insert(0, 1);
      })
      ..synchronize([0, 1, 2])
      ..runInTransaction(1, (final cnt) async {
        cnt..insert(1, 3)..insert(0, 2);
      })
      ..synchronize([0, 1, 2])
      ..runInTransaction(0, (final cnt) async {
        cnt..removeAt(1)..removeAt(1);
      })
      ..synchronize([0, 1, 2])
      ..runInTransaction(0, (final cnt) async {
        cnt.insert(0, 5);
      })
      ..synchronize([0, 1, 2]);
    await fleet.testSingleOrder();
  });

  await randomRelativeOrderTest(
      countInstances: 3, countEpochs: 2, countInsertions: 2, seed: 1);
  await randomRelativeOrderTest(
      countInstances: 2, countEpochs: 3, countInsertions: 2, seed: 2);
  await randomRelativeOrderTest(
      countInstances: 3, countEpochs: 3, countInsertions: 1, seed: 3);
}
