// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_devicesettings/fidl.dart';
import 'package:fidl_fuchsia_sys/fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:settings_protos/audio.pb.dart';
import 'package:settings_protos/setting_store_legacy.dart';

/// A factory for accessing the default stores for the setting types.
class SettingStoreFactoryLegacy {
  /// Used by stores that require access to fidl services.
  final ServiceProvider _provider;

  /// Passed into each store to access device settings.
  final DeviceSettingsManagerProxy _deviceSettingsManagerService =
      DeviceSettingsManagerProxy();

  SettingStoreFactoryLegacy(this._provider) {
    connectToService(_provider, _deviceSettingsManagerService.ctrl);
    _deviceSettingsManagerService.ctrl.onConnectionError =
        _handleSettingsConnectionError;
    _deviceSettingsManagerService.ctrl.error.then(
        (ProxyError error) => _handleSettingsConnectionError(error: error));
  }

  /// Returns the setting store for [Audio].
  SettingStoreLegacy<Audio> createAudioStore() {
    return new SettingStoreLegacy<Audio>(
        _deviceSettingsManagerService, 'Audio', new Audio());
  }

  /// Handles connection error to the settings service.
  void _handleSettingsConnectionError({ProxyError error}) {
    log.severe('Unable to connect to device settings service', error);
  }
}
