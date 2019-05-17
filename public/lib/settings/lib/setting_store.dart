// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl_fuchsia_devicesettings/fidl_async.dart';
import 'package:protobuf/protobuf.dart';
import 'package:fuchsia_logger/logger.dart';

/// A store for settings expressed as protobufs. The settings are persisted
/// in the device setting service as JSON.
class SettingStore<T extends GeneratedMessage> extends DeviceSettingsWatcher {
  /// The device settings key where the proto is stored.
  final String _settingsKey;

  /// Binding to watch changes in device settings.
  final DeviceSettingsWatcherBinding _deviceSettingsWatcherBinding =
      DeviceSettingsWatcherBinding();

  /// Connection to the device settings service.
  final DeviceSettingsManagerProxy _deviceSettingsManagerService;

  /// Used to publish changes to the setting.
  final StreamController<T> _updateStreamController =
      StreamController.broadcast();

  /// Since we do not have access to constructors with generics, an instance is
  /// provided at construction and used to operations. Note that protobufs
  /// (via [GeneratedMessage]) can spawn new instances and therefore this is
  /// only needed to seed.
  T _tmpSetting;

  SettingStore(
      this._deviceSettingsManagerService, this._settingsKey, this._tmpSetting);

  /// Adds a listener to be informed when the setting changes from the device
  /// settings service perspective.
  void addlistener(void onEvent(T value)) {
    _updateStreamController.stream.listen(onEvent);
  }

  /// Connects to the device settings service and fetches the initial value.
  /// This is separate from the constructor to allow clients to add a listener
  /// beforehand.
  Future<void> connect() async {
    await _deviceSettingsManagerService.watch(
        _settingsKey, _deviceSettingsWatcherBinding.wrap(this));

    await _fetch();
  }

  Future<void> _fetch() async {
    await _deviceSettingsManagerService
        .getString(_settingsKey)
        .then((response) {
      _tmpSetting.clear();
      _tmpSetting.mergeFromJson(response.val);
      _updateStreamController.add(_tmpSetting.clone());
    });
  }

  /// Persists the provided setting's values to device settings.
  Future<void> commit(T setting) async {
    await _deviceSettingsManagerService
        .setString(_settingsKey, setting.writeToJson())
        .catchError((e) =>
            log.warning('Could not persist value at key: $_settingsKey: ', e));
  }

  /// Upon a setting change, refetch value.
  @override
  Future<void> onChangeSettings(ValueType type) async {
    await _fetch();
  }
}
