// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:fidl_fuchsia_device_display/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';

/// This class abstracts away the DisplayManager fidl interface,
class Display {
  final DisplayManagerProxy _displayManagerService = DisplayManagerProxy();
  double _brightness;

  Display(ServiceProvider services) {
    connectToService(services, _displayManagerService.ctrl);
    _displayManagerService.ctrl.onConnectionError = _handleConnectionError;
    _displayManagerService.ctrl.error
        .then((ProxyError error) => _handleConnectionError(error: error));

    // fetch initial brightness
    _displayManagerService.getBrightness((bool success, double brightness) {
      if (success) {
        _brightness = brightness;
      }
    });
  }

  /// Returns the current brightness as a percentage of the maximum backlight
  /// brightness.
  double get brightness => _brightness;

  /// Sets the brightness to the specified percentage. If specified, the
  /// callback will be invoked with the updated backlight brightness value.
  Future<bool> setBrightness(double brightness) {
    var completer = Completer<bool>();

    if (_brightness == brightness || brightness < 0 || brightness > 1) {
      completer.complete(false);
      return completer.future;
    }

    _displayManagerService.setBrightness(brightness, (bool success) {
      if (success) {
        _brightness = brightness;
        completer.complete(true);
      } else {
        _displayManagerService
            .getBrightness((bool success, double brightnessVal) {
          if (success) {
            _brightness = brightnessVal;
          }
          completer.complete(false);
        });
      }
    });

    return completer.future;
  }

  /// Handles connection error to the display service.
  void _handleConnectionError({ProxyError error}) {
    log.severe('Unable to connect to display service', error);
  }
}
