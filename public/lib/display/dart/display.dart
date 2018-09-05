// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_device_display/fidl.dart';
import 'package:fidl_fuchsia_devicesettings/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';

/// This class abstracts away the fuchsia.device.display.Manager fidl interface,
class Display extends DeviceSettingsWatcher {
  final DeviceSettingsWatcherBinding _deviceSettingsWatcherBinding =
      DeviceSettingsWatcherBinding();
  final String _brightnessSettingsKey = 'Display.Brightness';

  // Used to publish brightness events.
  final StreamController<double> _brightnessStreamController =
      StreamController.broadcast();

  // Used to modify the physical display.
  final ManagerProxy _displayManagerService = ManagerProxy();

  // Used to store and retrieve user settings.
  final DeviceSettingsManagerProxy _deviceSettingsManagerService =
      DeviceSettingsManagerProxy();
  double _brightness;

  Display(ServiceProvider services) {
    connectToService(services, _displayManagerService.ctrl);
    _displayManagerService.ctrl.onConnectionError =
        _handleDisplayConnectionError;
    _displayManagerService.ctrl.error.then(
        (ProxyError error) => _handleDisplayConnectionError(error: error));

    connectToService(services, _deviceSettingsManagerService.ctrl);
    _deviceSettingsManagerService.ctrl.onConnectionError =
        _handleSettingsConnectionError;
    _deviceSettingsManagerService.ctrl.error.then(
        (ProxyError error) => _handleSettingsConnectionError(error: error));

    _deviceSettingsManagerService.watch(
        _brightnessSettingsKey, _deviceSettingsWatcherBinding.wrap(this), null);
    // Immediately get brightness on construction.
    _refreshBrightness();
  }

  /// Invoked during creation to refresh the internal cached brightness.
  void _refreshBrightness([bool force = false]) {
    if (brightness != null && !force) {
      return;
    }

    _deviceSettingsManagerService.getString(_brightnessSettingsKey,
        (String val, Status status) {
      if (status == Status.ok) {
        if (val == null || val.isEmpty) {
          return;
        }

        // If previous value exists, restore brightness.
        setBrightness(double.parse(val));
      } else {
        // If no previous value is found, fetch display brightness and set.
        // Setting is a noop from the device side, but makes sure our locale
        // cache is updated.
        _displayManagerService.getBrightness((bool success, double brightness) {
          if (success) {
            setBrightness(brightness);
          }
        });
      }
    });
  }

  void addListener(void onEvent(double brightness)) {
    _brightnessStreamController.stream.listen(onEvent);
  }

  // Cache the brightness so callers can retrieve it without reading the
  // device settings or display.
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
        _deviceSettingsManagerService.setString(
            _brightnessSettingsKey, brightness.toString(), (bool result) {
          // This is a silent failure. While we couldn't store the brightness,
          // it still took effect on the physical display.
          if (!result) {
            log.warning('Could not persist display brightness');
          }
        });

        _notifyBrightnessChange();
        completer.complete(true);
      } else {
        _displayManagerService
            .getBrightness((bool success, double brightnessVal) {
          if (success) {
            _brightness = brightnessVal;
            _notifyBrightnessChange();
          }
          completer.complete(false);
        });
      }
    });

    return completer.future;
  }

  /// Invoked internally to signal to a registered listener (if set) of a
  /// change in brightness.
  void _notifyBrightnessChange() {
    _brightnessStreamController.add(brightness);
  }

  /// Handles connection error to the display service.
  void _handleDisplayConnectionError({ProxyError error}) {
    log.severe('Unable to connect to display service', error);
  }

  /// Handles connection error to the settings service.
  void _handleSettingsConnectionError({ProxyError error}) {
    log.severe('Unable to connect to settings service', error);
  }

  @override
  void onChangeSettings(ValueType type) {
    _refreshBrightness(true);
  }
}
