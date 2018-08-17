// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// namespaced as material.dart defines a Step and State class as well.
import 'package:flutter/material.dart' show Widget;
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';

import 'widget_action_client.dart';
import 'widget_blueprint.dart';

/// Widget based action handling. This handler wraps the action to coordinate
/// behavior between the step and result.
class WidgetAction extends Action<WidgetBlueprint>
    implements ActionResultSender {
  WidgetActionClient _client;

  WidgetAction(
      Step step, ActionResultReceiver receiver, WidgetBlueprint blueprint)
      : super(step, blueprint, receiver);

  @override
  void launch() {
    _client = blueprint.createClient(this)..setState(State.started);
    blueprint.model.setCurrentAction(this);
  }

  String get title => _client.title;

  /// Called by owning host to generate layout for action.
  Widget build() {
    return _client.build();
  }

  @override
  void sendResult(String result) {
    onResult(result);
    _client.setState(State.finished);
  }
}
