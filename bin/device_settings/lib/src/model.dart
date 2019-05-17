// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_fuchsia_amber/fidl_async.dart' as amber;
import 'package:fidl_fuchsia_device_manager/fidl_async.dart' as devmgr;
import 'package:flutter/foundation.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_services/services.dart';
import 'package:lib.settings/device_info.dart';
import 'package:lib.widgets/model.dart';
import 'package:zircon/zircon.dart';

/// Clock ID of the system monotonic clock, which measures uptime in nanoseconds.
const int _zxClockMonotonic = 0;

const Duration _uptimeRefreshInterval = Duration(seconds: 1);

/// Model containing state needed for the device settings app.
class DeviceSettingsModel extends Model {
  /// Controller for amber (our update service).
  final amber.ControlProxy _amberControl = amber.ControlProxy();

  /// Placeholder time of last update, used to provide visual indication update
  /// was called.
  ///
  /// This will be removed when we have a more reliable way of showing update
  /// status.
  /// TODO: replace with better status info from update service
  DateTime _lastUpdate;

  /// Holds the time the source code was updated.
  DateTime _sourceDate;

  /// Length of time since system bootup.
  Duration _uptime;
  Timer _uptimeRefreshTimer;

  bool _showResetConfirmation = false;

  ValueNotifier<bool> channelPopupShowing = ValueNotifier<bool>(false);

  List<amber.SourceConfig> _channels;

  DeviceSettingsModel() {
    _onStart();
    channelPopupShowing.addListener(notifyListeners);
  }

  DateTime get lastUpdate => _lastUpdate;

  List<amber.SourceConfig> get channels => _channels ?? [];
  Iterable<String> get selectedChannels => channels
      .where((source) => source.statusConfig.enabled)
      .map((config) => config.id);

  /// Determines whether the confirmation dialog for factory reset should
  /// be displayed.
  bool get showResetConfirmation => _showResetConfirmation;

  DateTime get sourceDate => _sourceDate;

  Duration get uptime => _uptime;

  bool get updateCheckDisabled =>
      DateTime.now().isAfter(_lastUpdate.add(Duration(seconds: 60)));

  /// Checks for update from the update service
  Future<void> checkForUpdates() async {
    await _amberControl.checkForSystemUpdate();
    _lastUpdate = DateTime.now();
  }

  Future<void> selectChannel(amber.SourceConfig selectedConfig) async {
    channelPopupShowing.value = false;

    // Disable all other channels, since amber currently doesn't handle
    // more than one source well.
    for (amber.SourceConfig config in channels) {
      if (config.statusConfig.enabled) {
        await _amberControl.setSrcEnabled(config.id, false);
      }
    }

    if (selectedConfig != null) {
      await _amberControl.setSrcEnabled(selectedConfig.id, true);
    }
    await _updateSources();
  }

  Future<void> _updateSources() async {
    _channels = await _amberControl.listSrcs();
    notifyListeners();
  }

  void dispose() {
    _amberControl.ctrl.close();
    _uptimeRefreshTimer.cancel();
  }

  Future<void> _onStart() async {
    _sourceDate = DeviceInfo.getSourceDate();

    updateUptime();
    _uptimeRefreshTimer =
        Timer.periodic(_uptimeRefreshInterval, (_) => updateUptime());

    StartupContext.fromStartupInfo().incoming.connectToService(_amberControl);

    await _updateSources();
  }

  void updateUptime() {
    // System clock returns time since boot in nanoseconds.
    _uptime =
        Duration(microseconds: System.clockGet(_zxClockMonotonic) ~/ 1000);
    notifyListeners();
  }

  void factoryReset() async {
    if (showResetConfirmation) {
      final flagSet = await DeviceInfo.setFactoryResetFlag(shouldReset: true);
      log.severe('Factory Reset flag set successfully: $flagSet');

      final ChannelPair channels = ChannelPair();
      if (channels.status != 0) {
        log.severe('Unable to create channels: $channels.status');
        return;
      }

      int status = System.connectToService(
        '/svc/${devmgr.Administrator.$serviceName}',
        channels.second.passHandle());
      if (status != 0 ) {
        channels.first.close();
        log.severe('Unable to connect to device administrator service: $status');
        return;
      }

      final devmgr.AdministratorProxy admin = devmgr.AdministratorProxy();
      admin.ctrl.bind(InterfaceHandle<devmgr.Administrator>(channels.first));

      status = await admin.suspend(devmgr.suspendFlagReboot);
      if (status != 0) {
        log.severe('Reboot call failed with status: $status');
      }

      admin.ctrl.close();
    } else {
      _showResetConfirmation = true;
      notifyListeners();
    }
  }

  void cancelFactoryReset() {
    _showResetConfirmation = false;
    notifyListeners();
  }
}
