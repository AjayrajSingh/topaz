// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:lib.app_driver.dart/module_driver.dart';
import 'package:lib.schemas.dart/com.fuchsia.status.dart';

import 'wifi_settings_model.dart';

/// The model for the wifi settings module.
class WifiSettingsModuleModel extends WifiSettingsModel {
  final StatusEntityCodec _kStatusCodec = new StatusEntityCodec();

  ModuleDriver _moduleDriver;

  /// Constructor.
  WifiSettingsModuleModel() : super() {
    _moduleDriver = new ModuleDriver(onTerminate: close)..start();

    _updateStatus();
    addListener(_updateStatus);
  }

  void _updateStatus() {
    statusLabel.then((String statusLabel) {
      _moduleDriver.put(
          'status', new StatusEntityData(value: statusLabel), _kStatusCodec);
    });
  }
}
