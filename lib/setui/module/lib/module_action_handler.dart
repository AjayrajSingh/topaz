// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib_setiu_common/action_handler.dart';
import 'package:lib_setiu_common/step.dart';
import 'package:meta/meta.dart';

import 'module_action.dart';
import 'result_code_entity_codec.dart';

/// The link name used by the result helper to communicate back the step result.
/// It is defined here as the action handler must add the link parameter
/// mapping.
const String stepResultLinkName = 'setui_step_code_result';

/// Module based action launching.
class ModuleActionHandler {
  final Step _step;
  final ModuleAction _action;
  final ModuleDriver _driver;

  final ResultCodeEntityCodec _resultCodeEntityCodec =
      new ResultCodeEntityCodec();

  ModuleActionHandler(this._driver, this._step, this._action);

  /// Returns the name of the link to be used.
  @visibleForTesting
  String get linkKey => 'link=${_step.key}:${_step.action}';

  /// Implementation of [LaunchAction].
  void launch(ActionCallback callback) {
    // Create intent pointing to the action / handler combination.
    IntentBuilder intentBuilder =
        new IntentBuilder(action: _action.verb, handler: _action.handler)
          ..addParameterFromLink(linkKey, stepResultLinkName);

    // Watch the link for changes.
    _driver
        .watch(linkKey, _resultCodeEntityCodec, all: true)
        .listen((String resultCode) {
      final ActionResult result = new ActionResult(_step, resultCode);
      callback(result);
    });

    // Launch module.
    _driver.embedModule(name: _action.name, intent: intentBuilder.intent);
  }
}
