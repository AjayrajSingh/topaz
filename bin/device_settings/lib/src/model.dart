// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:fidl_fuchsia_amber/fidl.dart' as amber;
import 'package:lib.app.dart/app.dart';
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

  DeviceSettingsModel() {
    _onStart();
  }

  DateTime get lastUpdate => _lastUpdate;

  /// Determines whether the confirmation dialog for factory reset should
  /// be displayed.
  bool get showResetConfirmation => _showResetConfirmation;

  DateTime get sourceDate => _sourceDate;

  bool get updateCheckDisabled =>
      DateTime.now().isAfter(_lastUpdate.add(Duration(seconds: 60)));

  /// Checks for update from the update service
  void checkForUpdates() {
    _amberControl.checkForSystemUpdate((bool status) {
      _lastUpdate = DateTime.now();
    });
  }

  void dispose() {
    _amberControl.ctrl.close();
  }

  void _onStart() {
    final startupContext = StartupContext.fromStartupInfo();
    _sourceDate = DeviceInfo.getSourceDate();
    connectToService(startupContext.environmentServices, _amberControl.ctrl);
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
