// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fidl_fuchsia_amber/fidl.dart' as amber;
import 'package:lib.app.dart/app.dart';
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

  DeviceSettingsModel() {
    _onStart();
  }

  DateTime get lastUpdate => _lastUpdate;

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
    connectToService(startupContext.environmentServices, _amberControl.ctrl);
  }
}
