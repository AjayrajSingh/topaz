// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';
import 'package:lib_setui_flutter/widget_action_client.dart';
import 'package:lib_setui_flutter/widget_action_host.dart';
import 'package:lib_setui_flutter/widget_blueprint.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

class MockStep extends Mock implements Step {}

class MockActionResultReceiver extends Mock implements ActionResultReceiver {}

class MockStateModel extends Mock implements ActionStateModel {}

class MockWidgetActionClient extends Mock implements WidgetActionClient {}

void main() {
  // Verifies that an action can be properly launched from the roster and
  // the reported result is propagated back
  test('test_lifecycle', () {
    const String testActionName = 'test_action';
    const String testResult = 'test_result';

    final MockWidgetActionClient client = new MockWidgetActionClient();
    final MockStateModel stateModel = new MockStateModel();

    final MockStep step = new MockStep();
    final ActionResultReceiver resultReceiver = new MockActionResultReceiver();

    // Create Blueprint
    ActionResultSender actionResultSender;

    final WidgetBlueprint blueprint = new WidgetBlueprint(
        testActionName, stateModel, (ActionResultSender sender) {
      actionResultSender = sender;
      return client;
    });
    blueprint.assemble(step, resultReceiver).launch();

    // Ensure start was called
    verify(client.setState(State.started));

    // launch action and make sure client built
    verify(stateModel.setCurrentAction(captureAny)).captured.single.build();
    verify(client.build());

    reset(client);

    // Send result and verify received by ActionResultReceiver
    actionResultSender.sendResult(testResult);
    expect(verify(resultReceiver.onResult(captureAny)).captured.single.code,
        testResult);
    verify(client.setState(State.finished));
  });
}
