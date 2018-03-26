// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

/// The UI Model for state that can be updated outside the boundary of this
/// module via Link updates.
class ColorModel extends Model {
  /// Gets the color.
  Color get color => _color;
  Color _color = Colors.black;

  set color(Color value) {
    _color = value;
    // Update the UI.
    notifyListeners();
  }
}
