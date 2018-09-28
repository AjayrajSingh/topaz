// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: implementation_imports
import 'package:lib.app.dart/logging.dart';
import 'package:test/test.dart';

import '../crdt_test_framework/evaluation_order.dart';
import '../crdt_test_framework/node.dart';

void main() {
  setupLogger();

  test('EvaluationOrder operator ==', () {
    final n1 = new Node('1');
    final n2 = new Node('2');
    final n3 = new Node('3');
    expect(new EvaluationOrder([n1, n2, n3]),
        equals(new EvaluationOrder([n1, n2, n3])));
    expect(new EvaluationOrder([n1, n2, n3]),
        isNot(equals(new EvaluationOrder([n2, n1, n3]))));
  });

  final argumentErrorMatcher = throwsA(new TypeMatcher<ArgumentError>());

  test('Node restricted name', () {
    expect(() => new Node("f'o'o"), argumentErrorMatcher);
  });

  test('EvaluationOrder from list of ids', () {
    final n1 = new Node('1');
    final n2 = new Node('2');
    final n3 = new Node('3');
    final order132 =
        new EvaluationOrder.fromIds(['n-1', 'n-3', 'n-2'], [n1, n2, n3]);
    expect(order132, equals(new EvaluationOrder([n1, n3, n2])));
    expect(() => new EvaluationOrder.fromIds(['n-1', 'n-2'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        () => new EvaluationOrder.fromIds(
            ['n-1', 'n-2', 'n-3', 'n-1'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        () => new EvaluationOrder.fromIds(['n-1', 'n-2', 'n-1'], [n1, n2, n3]),
        argumentErrorMatcher);
    expect(
        new EvaluationOrder.fromIds(['n-1', 'n-3'], [n1, n2, n3],
            allowPartial: true),
        equals(new EvaluationOrder([n1, n3])));
  });
}
