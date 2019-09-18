// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_device_display/fidl_async.dart';
import 'package:fuchsia_services/services.dart';

/// This class abstracts away the fuchsia.device.display.Manager fidl interface,
class Display {
  // Used to publish brightness events.
  final StreamController<double> _brightnessStreamController =
      StreamController.broadcast();

  // Used to modify the physical display.
  final ManagerProxy _displayManagerService = ManagerProxy();

  double _brightness;

  // ignore: public_member_api_docs
  Display() {
    StartupContext.fromStartupInfo()
        .incoming
        .connectToService(_displayManagerService);

    // Immediately get brightness on construction.
    _refreshBrightness();
  }

  /// Invoked during creation to refresh the internal cached brightness.
  Future<void> _refreshBrightness([bool force = false]) async {
    if (brightness != null && !force) {
      return;
    }

    // TODO(4774): Search Stash storage to see if a persisted brightness value
    // already exists.
    final brightnessResult = await _displayManagerService.getBrightness();
    if (brightnessResult.success) {
      await setBrightness(brightnessResult.brightness);
    }
  }

  // ignore: public_member_api_docs
  void addListener(void onEvent(double brightness)) {
    _brightnessStreamController.stream.listen(onEvent);
  }

  // Cache the brightness so callers can retrieve it without reading the
  // device settings or display.
  // ignore: public_member_api_docs
  double get brightness => _brightness;

  /// Sets the brightness to the specified percentage. If specified, the
  /// callback will be invoked with the updated backlight brightness value.
  Future<bool> setBrightness(double brightness) async {
    var completer = Completer<bool>();

    if (_brightness == brightness || brightness < 0 || brightness > 1) {
      completer.complete(false);
      return completer.future;
    }

    final wasSuccessful =
        await _displayManagerService.setBrightness(brightness);

    if (wasSuccessful) {
      _brightness = brightness;
      // TODO(4774): Persist brightness update to Stash store.
      _notifyBrightnessChange();
      return true;
    } else {
      final brightness = await _displayManagerService.getBrightness();

      if (brightness.success) {
        _brightness = brightness.brightness;
        _notifyBrightnessChange();
      }
      return false;
    }
  }

  /// Invoked internally to signal to a registered listener (if set) of a
  /// change in brightness.
  void _notifyBrightnessChange() {
    _brightnessStreamController.add(brightness);
  }
}
