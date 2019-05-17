// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:convert';

import 'package:lib_setui_common/step.dart';
import 'package:test/test.dart';

void main() {
  // Verify basic [StepBuilder] functionality.
  test('test_builder', () {
    const String childKey1 = 'step1';
    const String childKey2 = 'step2';

    const String result1 = 'result1';
    const String result2 = 'result2';

    const String name = 'parent';
    const String action = 'start';

    // Create a parent node with two unique child actions.
    final Step parent = Step(name, action)
      ..addResult(result1, childKey1)
      ..addResult(result2, childKey2);

    // Ensure name is properly set.
    expect(parent.key, name);

    // Ensure action is properly set.
    expect(parent.action, action);

    // Check mappings from result to child step.
    expect(parent.getNext(result1), childKey1);
    expect(parent.getNext(result2), childKey2);

    // Expect nothing to be returned without a default set.
    expect(parent.getNext('unknown'), null);

    // Make sure next steps size and members is consistent.
    final Set<String> nextSteps = parent.nextSteps;

    expect(nextSteps.length, 2);
    expect(nextSteps.contains(childKey1), true);
    expect(nextSteps.contains(childKey2), true);
  });

  // Verify default step behavior.
  test('test_default', () {
    const String childKey = 'step1';
    const String defaultKey = 'defaultKey';

    const String result1 = 'result1';

    // Create parent with a single child node.
    final Step parent = Step('parent', 'start')
      ..addResult(result1, childKey)
      ..defaultTransition = defaultKey;

    // Ensure default is returned when no matching Step is found.
    expect(parent.getNext('unknown'), defaultKey);

    // Make sure the mapping still works in the presence of a default.
    expect(parent.getNext(result1), childKey);
  });

  // Ensures JSON encoding and decoding works properly
  test('test_json', () {
    final Step step1 = Step('fooKey', 'barAction')
      ..defaultTransition = 'bazDefault'
      ..addResult('result1', 'result1Key')
      ..addResult('result2', 'result2Key');

    final Step step2 = Step.fromJson(jsonDecode(jsonEncode(step1)));

    expect(step1, step2);
  });
}
