// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.module_resolver.dart/intent_builder.dart';
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';
import 'package:meta/meta.dart';

import 'module_blueprint.dart';
import 'result_code_entity_codec.dart';

/// The link name used by the result sender to communicate back the step result.
/// It is defined here as the action handler must add the link parameter
/// mapping.
const String stepResultLinkName = 'setui_step_code_result';

/// Module based action launching.
class ModuleAction extends Action {
  final ModuleBlueprint blueprint;

  final ResultCodeEntityCodec _resultCodeEntityCodec =
      new ResultCodeEntityCodec();

  ModuleAction(Step step, this.blueprint, ActionResultReceiver callback)
      : super(step, callback);

  /// Returns the name of the link to be used.
  @visibleForTesting
  String get linkKey => 'link=${step.key}:${step.action}';

  @override
  void launch() {
    // Create intent pointing to the action / handler combination.
    IntentBuilder intentBuilder =
        new IntentBuilder(action: blueprint.verb, handler: blueprint.handler)
          ..addParameterFromLink(linkKey, stepResultLinkName);

    // Watch the link for changes.
    blueprint.driver
        .watch(linkKey, _resultCodeEntityCodec, all: true)
        .listen(onResult);

    // Launch module.
    blueprint.driver
        .embedModule(name: blueprint.name, intent: intentBuilder.intent);
  }

  @override
  String toString() => linkKey;
}
