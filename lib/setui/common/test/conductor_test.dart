// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/conductor.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_common/syllabus.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockAction extends Mock implements Action<TestBlueprint> {}

class TestBlueprint extends Blueprint {
  final MockAction action = new MockAction();

  TestBlueprint(String name) : super(name, 'TestBlueprint');

  @override
  Action assemble(Step step, ActionResultReceiver callback) {
    return action;
  }
}

void main() {
  // Make sure first action is launched.
  test('test_start', () {
    final Step entry = new Step('step1', 'action1');
    final TestBlueprint actionBlueprint = new TestBlueprint('action1');

    final Syllabus syllabus = new Syllabus([entry], entry);

    final Roster roster = new Roster()..add(actionBlueprint);

    new Conductor(syllabus, roster).start();
    MockAction action = actionBlueprint.action;
    verify(action.launch());
  });

  // Ensure we proceed to the next step when the current step's action is
  // missing
  test('test_advance', () {
    final Step step2 = new Step('step2', 'action2');
    final TestBlueprint actionBlueprint = new TestBlueprint('action2');

    final Step entry = new Step('step1', 'action1')
      ..defaultTransition = step2.key;

    final Syllabus syllabus = new Syllabus([step2, entry], entry);

    final Roster roster = new Roster()..add(actionBlueprint);

    new Conductor(syllabus, roster).start();
    verify(actionBlueprint.action.launch());
  });
}
