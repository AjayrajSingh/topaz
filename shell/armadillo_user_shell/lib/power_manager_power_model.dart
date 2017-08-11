// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:apps.power-service.services/power_manager.fidl.dart';
import 'package:armadillo/power_model.dart';

/// Provides battery and charging information.
class PowerManagerPowerModel extends PowerModel {
  /// The power manager containing battery and charging information for the
  /// device.
  final PowerManager powerManager;

  final PowerManagerWatcherBinding _powerManagerWatcherBinding =
      new PowerManagerWatcherBinding();

  int _percentage;
  bool _isCharging;
  bool _hasBattery = true;

  /// Constructor.
  PowerManagerPowerModel({this.powerManager}) {
    powerManager.getBatteryStatus(_processStatus);
    powerManager.watch(
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
  bool get hasBattery => _hasBattery;

  /// Call to close any handles owned by this model.
  void close() {
    _powerManagerWatcherBinding.close();
  }

  void _processStatus(BatteryStatus status) {
    switch (status.status) {
      case Status.ok:
        if (_hasBattery != true) {
          _hasBattery = true;
          notifyListeners();
        }
        if (_percentage != status.level) {
          _percentage = status.level;
          notifyListeners();
        }
        if (_isCharging != status.charging) {
          _isCharging = status.charging;
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

typedef void _OnBatteryStatusChanged(BatteryStatus batteryStatus);

class _PowerManagerWatcherImpl extends PowerManagerWatcher {
  final _OnBatteryStatusChanged onBatteryStatusChanged;

  _PowerManagerWatcherImpl({this.onBatteryStatusChanged});

  @override
  void onChangeBatteryStatus(BatteryStatus batteryStatus) {
    onBatteryStatusChanged?.call(batteryStatus);
  }
}
