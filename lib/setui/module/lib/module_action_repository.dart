// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib_setiu_common/action_handler.dart';
import 'package:lib_setiu_common/step.dart';
import 'package:meta/meta.dart';

import 'module_action.dart';
import 'module_action_handler.dart';

/// Repository implementing [RetrieveAction] for Module-based actions.
class ModuleActionRepository {
  final Map<String, ModuleAction> _actionMap;

  ModuleActionRepository(this._actionMap);

  /// Returns a handler function for the given step or null if not found.
  LaunchAction getActionLauncher(Step step) {
    final ModuleAction action = getAction(step.action);

    if (action == null) {
      return null;
    }

    final ModuleActionHandler handler =
        new ModuleActionHandler(new ModuleDriver(), step, action);
    return handler.launch;
  }

  @visibleForTesting
  int get actionCount => _actionMap.keys.length;

  @visibleForTesting
  ModuleAction getAction(String action) => _actionMap[action];
}
