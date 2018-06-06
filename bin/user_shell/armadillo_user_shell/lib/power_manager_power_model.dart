// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:armadillo/now.dart';
import 'package:fidl_fuchsia_power/fidl.dart';

/// Provides battery and charging information.
class PowerManagerPowerModel extends PowerModel {
  /// The power manager containing battery and charging information for the
  /// device.
  final PowerManager powerManager;

  final PowerManagerWatcherBinding _powerManagerWatcherBinding =
      new PowerManagerWatcherBinding();

  int _percentage;
  bool _isCharging;
  bool _powerAdapterOnline;
  bool _hasBattery = true;
  Duration _batteryLifeRemaining;

  /// Constructor.
  PowerManagerPowerModel({this.powerManager}) {
    powerManager
      ..getBatteryStatus(_processStatus)
      ..watch(
        _powerManagerWatcherBinding.wrap(
          new _PowerManagerWatcherImpl(onBatteryStatusChanged: _processStatus),
        ),
      );
  }

  @override
  int get percentage => _percentage;

  @override
  bool get isReady => _percentage != null;

  @override
  bool get isCharging => _isCharging;

  @override
  bool get powerAdapterOnline => _powerAdapterOnline;

  @override
  bool get hasBattery => _hasBattery;

  @override
  Duration get batteryLifeRemaining => _batteryLifeRemaining;

  /// Call to close any handles owned by this model.
  void close() {
    _powerManagerWatcherBinding.close();
  }

  void _processStatus(BatteryStatus status) {
    switch (status.status) {
      case Status.ok:
        if (_hasBattery != status.batteryPresent) {
          _hasBattery = status.batteryPresent;
          notifyListeners();
        }

        int percentage = status.level.round();
        if (_percentage != percentage) {
          _percentage = percentage;
          notifyListeners();
        }

        if (_isCharging != status.charging) {
          _isCharging = status.charging;
          notifyListeners();
        }

        if (_powerAdapterOnline != status.powerAdapterOnline) {
          _powerAdapterOnline = status.powerAdapterOnline;
          notifyListeners();
        }

        Duration newBatteryLifeRemaining;
        if (status.remainingBatteryLife >= 0.0) {
          int hours = status.remainingBatteryLife.floor();
          int minutes = ((status.remainingBatteryLife - hours) * 60).floor();
          newBatteryLifeRemaining = new Duration(
            hours: hours,
            minutes: minutes,
          );
        }

        if (newBatteryLifeRemaining != _batteryLifeRemaining) {
          _batteryLifeRemaining = newBatteryLifeRemaining;
          notifyListeners();
        }

        break;
      default:
        if (_hasBattery != false) {
          _hasBattery = false;
          notifyListeners();
        }
        if (_percentage != null) {
          _percentage = null;
          notifyListeners();
        }
        if (_isCharging != null) {
          _isCharging = null;
          notifyListeners();
        }
        break;
    }
  }
}

class _PowerManagerWatcherImpl extends PowerManagerWatcher {
  final void Function(BatteryStatus batteryStatus) onBatteryStatusChanged;

  _PowerManagerWatcherImpl({this.onBatteryStatusChanged});

  @override
  void onChangeBatteryStatus(BatteryStatus batteryStatus) {
    onBatteryStatusChanged?.call(batteryStatus);
  }
}
