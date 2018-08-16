// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib_setui_common/action.dart';
import 'package:lib_setui_common/step.dart';

import 'module_action.dart';

/// A module-based action definition.
class ModuleBlueprint extends Blueprint {
  /// The module intent verb.
  final String verb;

  /// The package that contains the module.
  final String handler;

  final ModuleDriver driver;

  ModuleBlueprint(String name, this.verb, this.handler, this.driver)
      : super(name);

  @override
  Action assemble(Step step, ActionResultReceiver callback) {
    return new ModuleAction(step, this, callback);
  }
}
