// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The model for the link viewer module.
class LinkViewerModuleModel extends ModuleModel {
  /// The decoded JSON object fromt he Link's JSON.
  dynamic get decodedJson => _decodedJson;
  dynamic _decodedJson;
  String _lastJson;

  @override
  void onNotify(String json) {
    if (_lastJson == json) {
      return;
    }
    _lastJson = json;

    log.fine('JSON: $json');
    _decodedJson = JSON.decode(json);
    notifyListeners();
  }
}
