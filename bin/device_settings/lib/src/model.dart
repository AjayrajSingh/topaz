// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:fidl_fuchsia_amber/fidl.dart' as amber;
import 'package:flutter/foundation.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
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
  void checkForUpdates() {
    _amberControl.checkForSystemUpdate((_) => _lastUpdate = DateTime.now());
  }

  Future<void> selectChannel(amber.SourceConfig selectedConfig) async {
    channelPopupShowing.value = false;

    // Disable all other channels, since amber currently doesn't handle
    // more than one source well.
    for (amber.SourceConfig config in channels) {
      if (config.statusConfig.enabled) {
        await setSrcEnabled(config.id, enabled: false);
      }
    }

    if (selectedConfig != null) {
      await setSrcEnabled(selectedConfig.id, enabled: true);
    }
    _updateSources();
  }

  /// Wraps amber.setSrcEnabled to be asynchronous.
  Future<void> setSrcEnabled(String id, {@required bool enabled}) {
    final completer = Completer();
    _amberControl.setSrcEnabled(id, enabled, (_) => completer.complete());
    return completer.future;
  }

  void _updateSources() {
    _amberControl.listSrcs((srcs) {
      _channels = srcs;
      notifyListeners();
    });
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

    final startupContext = StartupContext.fromStartupInfo();
    connectToService(startupContext.environmentServices, _amberControl.ctrl);

    _updateSources();
  }

  void updateUptime() {
    // System clock returns time since boot in nanoseconds.
    _uptime =
        Duration(microseconds: System.clockGet(_zxClockMonotonic) ~/ 1000);
    notifyListeners();
  }

  void factoryReset() async {
    if (showResetConfirmation) {
      // Reset has been confirmed, perform reset.
      var dm = File('/dev/misc/dmctl');
      if (dm.existsSync()) {
        final flagSet = await DeviceInfo.setFactoryResetFlag(shouldReset: true);
        log.severe('Factory Reset flag set successfully: $flagSet');
        dm.writeAsStringSync('reboot', flush: true);
      } else {
        log.severe('dmctl unable to be found.');
      }
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
