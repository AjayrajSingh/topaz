// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:lib.widgets/model.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const String _kBatteryUrlPrefix = 'packages/armadillo/res/ic_battery_';
const String _kBatteryUrlSuffix = '_white_48dp.png';

/// Provides battery and charging information.
abstract class PowerModel extends Model {
  /// Wraps [ModelFinder.of] for this [Model]. See [ModelFinder.of] for more
  /// details.
  static PowerModel of(BuildContext context) =>
      new ModelFinder<PowerModel>().of(context);

  /// The battery percentage from 0 to 100.
  int get percentage;

  /// Returns true if [isCharging] and [percentage] will return valid values.
  bool get isReady;

  /// Returns true if the battery is charging.
  bool get isCharging;

  /// Returns true if the power adapter is online.
  bool get powerAdapterOnline;

  /// Returns true if the device has a battery.
  bool get hasBattery;

  /// The text associated with the current battery percentage.
  String get batteryText {
    if (!isReady) {
      return '';
    }
    if (isCharging || powerAdapterOnline || batteryLifeRemaining == null) {
      return '$percentage%';
    }
    String hours = '${batteryLifeRemaining.inHours}';
    int intMinutes = batteryLifeRemaining.inMinutes % 60;
    String minutes = intMinutes >= 10 ? '$intMinutes' : '0$intMinutes';
    return '$hours:$minutes';
  }

  /// The image associated with the current power status.
  String get batteryImageUrl {
    if (!hasBattery) {
      return '';
    }

    if (!isReady) {
      return '${_kBatteryUrlPrefix}unknown$_kBatteryUrlSuffix';
    }

    if (percentage <= 10 && !isCharging) {
      return '${_kBatteryUrlPrefix}alert$_kBatteryUrlSuffix';
    }

    String imageValue = 'full';
    if (percentage <= 20) {
      imageValue = '20';
    } else if (percentage <= 30) {
      imageValue = '30';
    } else if (percentage <= 50) {
      imageValue = '50';
    } else if (percentage <= 60) {
      imageValue = '60';
    } else if (percentage <= 80) {
      imageValue = '80';
    } else if (percentage <= 90) {
      imageValue = '90';
    }

    return '$_kBatteryUrlPrefix'
        '${isCharging || powerAdapterOnline ? 'charging_' : ''}'
        '$imageValue$_kBatteryUrlSuffix';
  }

  /// The remaining battery life.  Null if no battery or battery is not
  /// discharging.
  Duration get batteryLifeRemaining;
}
