// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';

/// The model for the link viewer module.
class LinkViewerModuleModel extends ModuleModel {
  /// The decoded JSON object fromt he Link's JSON.
  dynamic get decodedJson => _decodedJson;
  dynamic _decodedJson;
  String _lastJson;

  @override
  void onNotify(String encoded) {
    if (_lastJson == encoded) {
      return;
    }
    _lastJson = encoded;

    log.fine('JSON: $json');
    _decodedJson = json.decode(encoded);
    notifyListeners();
  }
}
