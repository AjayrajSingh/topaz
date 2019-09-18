// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:lib.display.dart/display.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.display.dart/display.dart' show Display;

/// A Flutter model to interact with Display device and notify listeners of any
/// state changes.
class DisplayPolicyBrightnessModel extends Model {
  /// Returns the minimum brightness level.
  static const double minLevel = 0.0;

  /// Returns the maximum brightness level.
  static const double maxLevel = 1.0;

  final Display _display;

  // ignore: public_member_api_docs
  DisplayPolicyBrightnessModel(this._display) {
    _display.addListener((double brightness) {
      notifyListeners();
    });

    if (_display.brightness != null) {
      notifyListeners();
    }
  }

  /// Sets the brightness of the display. value should be a percentage of max
  /// brightness between the minimum and maximum level defined above.
  set brightness(double brightness) => _setBrightness(brightness);

  void _setBrightness(double brightness) {
    _display.setBrightness(brightness);
  }

  /// Returns the display brightness.
  double get brightness =>
      max(minLevel, min(maxLevel, _display.brightness ?? minLevel));
}
