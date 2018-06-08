// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:armadillo/now.dart';
import 'package:flutter/widgets.dart';
import 'package:fidl_fuchsia_timezone/fidl.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const String _kLocationHomeWorkTopic = 'location/home_work';
const String _kActivityWalking = 'activity/walking';
const List<String> _kTopics = const <String>[
  _kLocationHomeWorkTopic,
];

const String _kContextConfig = '/system/data/sysui/contextual_config.json';

const String _kLastUpdate = '/system/data/build/last-update';

const String _kMode = 'mode';
const String _kModeNormal = 'normal';
const String _kModeEdgeToEdge = 'edgeToEdge';

/// Provides assets and text based on context.
class ContextProviderContextModel extends ContextModel {
  /// Provides time zone information.
  final Timezone timezone;

  Map<String, String> _contextualWifiNetworks = <String, String>{};
  Map<String, String> _contextualLocations = <String, String>{};
  Map<String, String> _contextualTimeOnly = <String, String>{};
  Map<String, String> _contextualDateOnly = <String, String>{};
  Map<String, String> _contextualBackgroundImages = <String, String>{};
  String _location = 'unknown';
  String _activity = 'unknown';
  String _userName;
  String _userImageUrl;
  DateTime _buildTimestamp;
  DeviceMode _deviceMode = DeviceMode.normal;

  /// Constructor.
  ContextProviderContextModel({@required this.timezone})
      : assert(timezone != null) {
    // Gets the current timezone ID so that the correct zone can be
    // highlighted in the timezone picker when timezoneId is retrieved
    // through the 'get' function.  This must be called as the timezone persists
    // in non-volatile storage.
    timezone.getTimezoneId((String zoneId) {
      super.timezoneId = zoneId;
    });
  }

  @override
  set timezoneId(String newTimezoneId) {
    if (super.timezoneId != newTimezoneId) {
      timezone.setTimezone(
        newTimezoneId,
        (bool status) {
          if (status) {
            super.timezoneId = newTimezoneId;
            notifyListeners();
          }
        },
      );
    }
  }

  /// The current background image to use.
  @override
  ImageProvider get backgroundImageProvider {
    String backgroundImageFile = _contextualBackgroundImages[_activity] ??
        _contextualBackgroundImages[_location] ??
        _contextualBackgroundImages['default'];
    if (backgroundImageFile == null) {
      return super.backgroundImageProvider;
    }
    Uri uri = Uri.parse(backgroundImageFile);
    if (uri.scheme.startsWith('http')) {
      return new NetworkImage(backgroundImageFile);
    } else {
      return new FileImage(new File(backgroundImageFile));
    }
  }

  /// TODO(apwilson): Remove this.
  /// The current wifi network.  For testing purposes only.
  @override
  String get wifiNetwork =>
      _contextualWifiNetworks[_activity] ??
      _contextualWifiNetworks[_location] ??
      super.wifiNetwork;

  /// The current contextual location.
  @override
  String get contextualLocation =>
      _contextualLocations[_activity] ??
      _contextualLocations[_location] ??
      super.contextualLocation;

  /// TODO(apwilson): Remove this.
  /// The current time.  For testing purposes only.
  @override
  String get timeOnly =>
      _contextualTimeOnly[_activity] ??
      _contextualTimeOnly[_location] ??
      super.timeOnly;

  /// TODO(apwilson): Remove this.
  /// The current date.  For testing purposes only.
  @override
  String get dateOnly =>
      _contextualDateOnly[_activity] ??
      _contextualDateOnly[_location] ??
      super.dateOnly;

  @override
  String get userName => _userName;

  @override
  String get userImageUrl => _userImageUrl;

  @override
  DateTime get buildTimestamp => _buildTimestamp;

  @override
  DeviceMode get deviceMode => _deviceMode;

  /// Called when the device profile changes.
  void onDeviceProfileChanged(Map<String, String> deviceProfile) {
    switch (deviceProfile[_kMode]) {
      case _kModeNormal:
        if (_deviceMode != DeviceMode.normal) {
          _deviceMode = DeviceMode.normal;
          notifyListeners();
        }
        break;
      case _kModeEdgeToEdge:
        if (_deviceMode != DeviceMode.edgeToEdge) {
          _deviceMode = DeviceMode.edgeToEdge;
          notifyListeners();
        }
        break;
      default:
        // Unknown mode.
        break;
    }
  }

  /// Called when the user information changes.
  void onUserUpdated(String userName, String userImageUrl) {
    _userName = userName;
    _userImageUrl = userImageUrl != null && userImageUrl.isNotEmpty
        ? userImageUrl
        : 'packages/armadillo/res/guest_user_image.png';
    notifyListeners();
  }

  /// Called when the user selected wallpapers change.
  void onWallpaperChosen(List<String> images) {
    log.info('Wallpapers chosen: $images');
    _contextualBackgroundImages['default'] =
        images.isNotEmpty ? images.first : null;
    notifyListeners();
  }

  /// Called when context changes.
  void onContextUpdated(Map<String, String> context) {
    if (context[_kLocationHomeWorkTopic] != null) {
      Map<String, String> locationJson = convert.json.decode(
        context[_kLocationHomeWorkTopic],
      );
      _location = locationJson['location'];
    }

    if (context[_kActivityWalking] != null) {
      Map<String, String> activityJson = convert.json.decode(
        context[_kActivityWalking],
      );
      _activity = activityJson['activity'];
    }
    notifyListeners();
  }

  /// Loads and parses the configuration file used by this model.
  Future<Null> load() async {
    String json = new File(_kContextConfig).readAsStringSync();
    final Map<String, Map<String, String>> decodedJson =
        convert.json.decode(json);
    _contextualWifiNetworks = decodedJson['wifi_network'];
    _contextualLocations = decodedJson['location'];
    _contextualTimeOnly = decodedJson['time_only'];
    _contextualDateOnly = decodedJson['date_only'];
    _contextualBackgroundImages = decodedJson['background_image'];

    String lastUpdate = new File(_kLastUpdate).readAsStringSync();
    log.info('Build timestamp: ${lastUpdate.trim()}');
    try {
      _buildTimestamp = DateTime.parse(lastUpdate.trim());
    } on FormatException {
      log.warning('Could not parse build timestamp! ${lastUpdate.trim()}');
    }

    notifyListeners();
  }

  /// The list of topics this model wants updates on.
  static List<String> get topics => _kTopics;
}
