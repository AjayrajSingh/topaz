// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:fuchsia_logger/logger.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/evaluation_order.dart';
import '../crdt_test_framework/node.dart';

void main() {
  setupLogger();

  test('EvaluationOrder operator ==', () {
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    expect(EvaluationOrder([n1, n2, n3]),
        equals(EvaluationOrder([n1, n2, n3])));
    expect(EvaluationOrder([n1, n2, n3]),
        isNot(equals(EvaluationOrder([n2, n1, n3]))));
  });

  final argumentErrorMatcher = throwsA(TypeMatcher<ArgumentError>());

  test('Node restricted name', () {
    expect(() => Node("f'o'o"), argumentErrorMatcher);
  });

  test('EvaluationOrder from list of ids', () {
    final n1 = Node('1');
    final n2 = Node('2');
    final n3 = Node('3');
    final order132 =
        EvaluationOrder.fromIds(['n-1', 'n-3', 'n-2'], [n1, n2, n3]);
    expect(order132, equals(EvaluationOrder([n1, n3, n2])));
    expect(() => EvaluationOrder.fromIds(['n-1', 'n-2'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        () => EvaluationOrder.fromIds(
            ['n-1', 'n-2', 'n-3', 'n-1'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        () => EvaluationOrder.fromIds(['n-1', 'n-2', 'n-1'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        EvaluationOrder.fromIds(['n-1', 'n-3'], [n1, n2, n3],
            allowPartial: true),
        equals(EvaluationOrder([n1, n3])));
  });
}
