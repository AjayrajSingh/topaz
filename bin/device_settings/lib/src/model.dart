// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:fidl_fuchsia_amber/fidl_async.dart' as amber;
import 'package:flutter/foundation.dart';
import 'package:lib.app.dart/app_async.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:lib.settings/device_info.dart';
import 'package:lib.widgets/model.dart';

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
  }

  Future<void> _onStart() async {
    final startupContext = StartupContext.fromStartupInfo();
    _sourceDate = DeviceInfo.getSourceDate();
    await connectToService(
        startupContext.environmentServices, _amberControl.ctrl);

    await _updateSources();
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
