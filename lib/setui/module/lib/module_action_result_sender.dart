// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib_setui_common/action.dart';

import 'module_action.dart';
import 'result_code_entity_codec.dart';

/// An implementation of [ActionResultSender] to send results back from the client
/// module.
class ModuleActionResultSender extends ActionResultSender {
  /// The driver to write the result to.
  // TODO: Refactor this class to use the new SDK instead of deprecated API
  // ignore: deprecated_member_use
  final ModuleDriver _driver;

  /// The codec to encode the data with.
  final ResultCodeEntityCodec _codec = new ResultCodeEntityCodec();

  ModuleActionResultSender(this._driver);

  /// Writes result to a watched module link.
  @override
  void sendResult(String result) {
    _driver.put(stepResultLinkName, result, _codec);
  }
}
