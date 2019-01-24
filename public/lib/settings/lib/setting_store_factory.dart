// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_devicesettings/fidl_async.dart';
import 'package:fuchsia_services/services.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:settings_protos/audio.pb.dart';
import 'package:settings_protos/setting_store.dart';

/// A factory for accessing the default stores for the setting types.
class SettingStoreFactory {
  /// Passed into each store to access device settings.
  final DeviceSettingsManagerProxy _deviceSettingsManagerService =
      DeviceSettingsManagerProxy();

  SettingStoreFactory() {
    try {
      connectToEnvironmentService(_deviceSettingsManagerService);
    } catch (error) {
      log.severe('Unable to connect to device settings service', error);
    }
  }

  /// Returns the setting store for [Audio].
  SettingStore<Audio> createAudioStore() {
    return new SettingStore<Audio>(
        _deviceSettingsManagerService, 'Audio', new Audio());
  }
}
