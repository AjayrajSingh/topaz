// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'dart:async';

import 'package:fidl_fuchsia_ui_input/fidl_async.dart'
    show
        ImeService,
        ImeServiceProxy,
        ImeVisibilityService,
        ImeVisibilityServiceProxy;
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_services/services.dart';

/// Handles connecting to [ImeVisibilityService] and [ImeService] to show
/// and hide the keyboard.
class KeyboardDisplay {
  final ImeServiceProxy _imeProxy = ImeServiceProxy();
  final ImeVisibilityServiceProxy _imeVisibilityProxy =
      ImeVisibilityServiceProxy();
  final StreamController<bool> _keyboardStreamController =
      StreamController.broadcast();

  bool _keyboardVisible;

  KeyboardDisplay() {
    StartupContext.fromStartupInfo().incoming.connectToService(_imeProxy);
    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(_imeVisibilityProxy);

    _imeVisibilityProxy.onKeyboardVisibilityChanged
        .listen(_onVisibilityChanged);
  }

  /// Adds a listener to [KeyboardDisplay] for changes in keyboard
  /// visibility.
  void addListener(void onEvent(bool showKeyboard)) {
    _keyboardStreamController.stream.listen(onEvent);
  }

  /// Cache the visibility so callers can retrieve it without reading the
  /// [ImeVisibilityService].
  bool get keyboardVisible => _keyboardVisible;

  /// Sets the visibility of the keyboard.
  ///
  /// Note: triggers [ImeVisibilityService].
  set keyboardVisible(bool visible) =>
      visible ? _imeProxy.showKeyboard() : _imeProxy.hideKeyboard();

  /// Called when keyboard should be shown or hidden.
  void _onVisibilityChanged(bool visible) {
    _log(Level.SEVERE, 'onVisibilityChanged: $visible');
    _keyboardVisible = visible;
    _notifyKeyboardVisibilityChange();
  }

  /// Invoked internally to signal to any registered listener of a change
  /// in keyboard visibility.
  void _notifyKeyboardVisibilityChange() =>
      _keyboardStreamController.add(keyboardVisible);

  void _log(Level level, String message, [Object error]) {
    log.log(level, message, 'keyboard_display', error, null);
  }
}
