// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;

import 'package:lib.app.dart/logging.dart';
import 'package:lib.widgets.dart/model.dart';

/// The model for the link viewer module.
class LinkViewerModel extends Model {
  /// The decoded JSON object from the Link's JSON.
  dynamic get decodedJson => _decodedJson;
  dynamic _decodedJson;
  String _lastJson;

  /// Called when the model receives data
  void onData(String encoded) {
    if (_lastJson == encoded) {
      return;
    }
    _lastJson = encoded;

    log.fine('JSON: $json');
    try {
      _decodedJson = json.decode(encoded);
      notifyListeners();
      //ignore: avoid_catches_without_on_clauses
    } catch (e) {
      log.info('Failed to decode link data: $e');
    }
  }
}
