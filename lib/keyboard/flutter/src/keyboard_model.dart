// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_cobalt/fidl.dart';

import 'package:lib.app.dart/logging.dart';
import 'package:topaz.lib.keyboard.dart/keyboard_display.dart';
import 'package:topaz.lib.shell/models/overlay_position_model.dart';
import 'package:lib.widgets/model.dart';

export 'package:topaz.lib.keyboard.dart/keyboard_display.dart'
    show KeyboardDisplay;

/// Handles connecting to ImeVisibilityService and showing/hiding the keyboard.
class KeyboardModel extends Model {
  final KeyboardDisplay _keyboardDisplay;

  /// Overlay model used to show and hide the keyboard.
  OverlayPositionModel _overlayPositionModel;

  /// The elevation at which the keyboard overlay is displayed.
  final double keyboardElevation;

  KeyboardModel(
    this._keyboardDisplay, {
    OverlayPositionModel overlayPositionModel,
    this.keyboardElevation = 0.0,
  })  : assert(_keyboardDisplay != null),
        _overlayPositionModel = overlayPositionModel {
    setupLogger(name: 'keyboard_model');
    _keyboardDisplay.addListener((visible) => notifyListeners());
  }

  /// Returns whether the keyboard is visible or hidden.
  bool get keyboardVisible => _keyboardDisplay.keyboardVisible;

  /// Returns whether the keyboard is visible or hidden.
  OverlayPositionModel get overlayPositionModel =>
      _overlayPositionModel ??= OverlayPositionModel(
        logger: LoggerProxy(),
        traceName: 'Keyboard',
        noInteractionTimeout: null,
      );

  /// Shows or hides the keyboard.
  set keyboardVisible(bool visible) =>
      _keyboardDisplay.keyboardVisible = visible;

  @override
  void notifyListeners() {
    super.notifyListeners();
    keyboardVisible ? overlayPositionModel.show() : overlayPositionModel.hide();
  }
}
