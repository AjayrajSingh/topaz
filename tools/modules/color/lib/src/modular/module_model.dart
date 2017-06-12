// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:flutter/material.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.widgets/modular.dart';
import 'package:util/parse_int.dart';

/// The model for the color module.
class ColorModuleModel extends ModuleModel {
  /// Gets the color.
  Color get color => _color;
  Color _color = Colors.black;

  @override
  void onNotify(String json) {
    log.fine('JSON: $json');
    // Expects Link to look something like this:
    // { "color" : 255 } or { "color" : '0xFF1DE9B6' }
    final dynamic doc = JSON.decode(json);
    if (doc is Map && (doc['color'] is int || doc['color'] is String)) {
      int colorValue = parseInt(doc['color']);
      _color = new Color(colorValue);
      notifyListeners();
    }
  }
}
