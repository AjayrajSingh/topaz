// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setiu_common/step.dart';
import 'package:test/test.dart';

void main() {
  // Verify basic [StepBuilder] functionality.
  test('test_builder', () {
    final Step child1 = new Step('step1', 'action1');
    final Step child2 = new Step('step2', 'action2');

    const String result1 = 'result1';
    const String result2 = 'result2';

    const String name = 'parent';
    const String action = 'start';

    // Create a parent node with two unique child actions.
    final Step parent = new Step(name, action)
      ..addResult(result1, child1)
      ..addResult(result2, child2);

    // Ensure name is properly set.
    expect(parent.key, name);

    // Ensure action is properly set.
    expect(parent.action, action);

    // Check mappings from result to child step.
    expect(parent.getNext(result1), child1);
    expect(parent.getNext(result2), child2);

    // Expect nothing to be returned without a default set.
    expect(parent.getNext('unknown'), null);

    // Make sure next steps size and members is consistent.
    final Set<Step> nextSteps = parent.nextSteps;

    expect(nextSteps.length, 2);
    expect(nextSteps.contains(child1), true);
    expect(nextSteps.contains(child2), true);
  });

  // Verify default step behavior.
  test('test_default', () {
    final Step child1 = new Step('step1', 'action1');
    final Step defaultStep = new Step('default', 'action');

    const String result1 = 'result1';

    // Create parent with a single child node.
    final Step parent = new Step('parent', 'start')
      ..addResult(result1, child1)
      ..defaultTransition = defaultStep;

    // Ensure default is returned when no matching Step is found.
    expect(parent.getNext('unknown'), defaultStep);

    // Make sure the mapping still works in the presence of a default.
    expect(parent.getNext(result1), child1);
  });
}
