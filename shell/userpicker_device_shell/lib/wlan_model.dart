// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:lib.wlan.fidl/wlan_service.fidl.dart';
import 'package:lib.widgets/model.dart';

/// Provides wlan information.
class WlanModel extends Model {
  /// The wlan containing wifi information for the device.
  final Wlan wlan;

  /// How often to poll the wlan for wifi information.
  final Duration updatePeriod;

  List<AccessPoint> _accessPoints = <AccessPoint>[];

  /// Constructor.
  WlanModel({
    this.wlan,
    this.updatePeriod: const Duration(seconds: 20),
  }) {
    _update();
    new Timer.periodic(updatePeriod, (_) {
      _update();
    });
  }

  void _update() {
    wlan.scan(new ScanRequest()..timeout = 15, (ScanResult scanResult) {
      if (scanResult.error.code == ErrCode.ok) {
        List<AccessPoint> accessPoints = <AccessPoint>[];
        for (Ap ap in scanResult.aps) {
          accessPoints.add(
            new AccessPoint(
              name: ap.ssid,
              signalStrength: ap.lastRssi.toDouble(),
              isSecure: ap.isSecure,
            ),
          );
        }
        accessPoints.sort((AccessPoint a, AccessPoint b) {
          if (b.signalStrength == a.signalStrength) {
            return 0;
          }
          if (a.signalStrength > b.signalStrength) {
            return -1;
          }
          return 1;
        });
        _accessPoints = accessPoints;
        notifyListeners();
      } else {
        _accessPoints = <AccessPoint>[];
      }
    });
  }

  /// The current list of access points.
  List<AccessPoint> get accessPoints => _accessPoints.toList();
}

/// An Access point you can connect to via wifi.
class AccessPoint {
  /// Name of the access point.
  final String name;

  /// The signal strength of the access point.
  final double signalStrength;

  /// True if this access point is secured.
  final bool isSecure;

  /// Constructor.
  AccessPoint({this.name, this.signalStrength, this.isSecure});

  /// The image url for an icon representing the signal strength for this access
  /// point.
  String get url {
    int percent = ((_getInt8(signalStrength.round()) + 100) * 2).clamp(0, 100);
    int bars = (percent > 80)
        ? 4
        : (percent > 60) ? 3 : (percent > 40) ? 2 : (percent > 20) ? 1 : 0;
    return 'packages/userpicker_device_shell/res/'
        'ic_signal_wifi_${bars}_bar_${isSecure && bars > 0 ? 'lock_' : ''}white_48dp.png';
  }

  int _getInt8(int uint8) {
    if (uint8 > math.pow(2, 7) - 1) {
      return uint8 - math.pow(2, 8);
    }
    return uint8;
  }

  @override
  String toString() => 'AccessPoint($name => $signalStrength)';
}
