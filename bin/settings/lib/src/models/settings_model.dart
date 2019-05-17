// Copyright 2018 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:fidl_fuchsia_ui_views/fidl_async.dart';
import 'package:flutter/material.dart';
import 'package:fuchsia_logger/logger.dart';
import 'package:fuchsia_modular/module.dart';
import 'package:fuchsia_scenic_flutter/child_view.dart' show ChildView;
import 'package:fuchsia_scenic_flutter/child_view_connection.dart';
import 'package:intl/intl.dart';
import 'package:lib.settings/device_info.dart';
import 'package:lib.widgets/model.dart';

import '../setting_entry.dart';
import 'settings_status.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

typedef ListRowBuilder = Widget Function(BuildContext context);

/// Model for settings view.
class SettingsModel extends Model {
  String _networkAddresses;

  SettingsStatus _settingsStatus;

  HashMap<String, _CachedModule> _cachedModules;

  DateTime _testDeviceSourceDate;

  /// Constructor.
  SettingsModel() {
    initialize();
  }

  // Exposed for testing.
  void initialize() {
    _cachedModules = HashMap();
    // Explicitly ignore intents
    Module().registerIntentHandler(NoopIntentHandler());
    _settingsStatus = SettingsStatus()..addListener(notifyListeners);
    _setNetworkAddresses();
  }

  ChildView getModule(SettingEntry entry) {
    if (!_cachedModules.containsKey(entry.id)) {
      entry.embedModule().then((EmbeddedModule module) {
        _cachedModules[entry.id] = _CachedModule(module);
        notifyListeners();
      });
    }
    return _cachedModules[entry.id]?.childView;
  }

  /// Fetches and sets the addresses of all network interfaces delimited by space.
  Future<void> _setNetworkAddresses() async {
    var interfaces = await NetworkInterface.list();
    _networkAddresses = interfaces
        .expand((NetworkInterface interface) => interface.addresses)
        .map((InternetAddress address) => address.address)
        .join(' ');
    notifyListeners();
  }

  /// Returns the addresses of all network interfaces delimited by space.
  String get networkAddresses {
    return _networkAddresses;
  }

  /// Returns the hostname of the running device.
  String get hostname => Platform.localHostname;

  /// Returns the build info, if build info file is found on the system image.
  String get buildInfo {
    final DateTime buildTimeStamp = _testDeviceSourceDate != null
        ? _testDeviceSourceDate
        : DeviceInfo.getSourceDate();

    if (buildTimeStamp != null) {
      final builtAt =
          DateFormat('H:mm', 'en_US').format(buildTimeStamp).toLowerCase();
      final builtOn =
          DateFormat('MMM dd, yyyy', 'en_US').format(buildTimeStamp);
      // The time zone is hardcoded because DateFormat and DateTime currently doesn't
      // support time zones.
      return 'Built at $builtAt UTC on $builtOn';
    } else {
      log.warning('Last built time doesn\'t exist!');
    }
    return null;
  }

  /// Returns the wifi status.
  String get wifiStatus => _settingsStatus.wifiStatus;

  /// Returns the datetime status.
  String get datetimeStatus => _settingsStatus.timezoneStatus;

  set testDeviceSourceDate(DateTime testDeviceSourceDate) =>
      _testDeviceSourceDate = testDeviceSourceDate;
}

/// A helper class which holds a reference to the [EmbeddedModule]
/// and creates the [childView] on demand.
class _CachedModule {
  final EmbeddedModule _embeddedModule;
  ChildView _childView;

  /// Returns an instance of the [ChildView] for this module.
  ChildView get childView {
    return _childView ??= _makeChildView();
  }

  _CachedModule(this._embeddedModule);

  ChildView _makeChildView() => ChildView(
      connection: ChildViewConnection(
          ViewHolderToken(value: _embeddedModule.viewHolderToken.value)));
}
