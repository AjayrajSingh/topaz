// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib_setiu_common/action_handler.dart';

import 'module_action_handler.dart';
import 'result_code_entity_codec.dart';

/// Implementation of [SendResult] for modules.
class ModuleResultHelper {
  // The driver to write the result to.
  final ModuleDriver _driver;

  // The codec to encode the data with.
  final ResultCodeEntityCodec _codec = new ResultCodeEntityCodec();

  ModuleResultHelper(this._driver);

  // Writes result to a watched module link.
  void sendResult(String result) {
    _driver.put(stepResultLinkName, result, _codec);
  }
}
