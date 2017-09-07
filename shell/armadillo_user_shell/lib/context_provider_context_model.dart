// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:armadillo/context_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lib.logging/logging.dart';

export 'package:lib.widgets/model.dart'
    show ScopedModel, Model, ScopedModelDescendant;

const String _kBackgroundImage = 'packages/armadillo/res/Background.jpg';

const String _kLocationHomeWorkTopic = 'location/home_work';
const String _kActivityWalking = 'activity/walking';
const List<String> _kTopics = const <String>[
  _kLocationHomeWorkTopic,
];

const String _kContextConfig = '/system/data/sysui/contextual_config.json';

/// Provides assets and text based on context.
class ContextProviderContextModel extends ContextModel {
  Map<String, String> _contextualWifiNetworks = <String, String>{};
  Map<String, String> _contextualLocations = <String, String>{};
  Map<String, String> _contextualTimeOnly = <String, String>{};
  Map<String, String> _contextualDateOnly = <String, String>{};
  Map<String, String> _contextualBackgroundImages = <String, String>{};
  String _location = 'unknown';
  String _activity = 'unknown';
  String _userName;
  String _userImageUrl;

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

  /// Called when the user information changes.
  void onUserUpdated(String userName, String userImageUrl) {
    _userName = userName;
    _userImageUrl = userImageUrl;
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
      Map<String, String> locationJson = convert.JSON.decode(
        context[_kLocationHomeWorkTopic],
      );
      _location = locationJson['location'];
    }

    if (context[_kActivityWalking] != null) {
      Map<String, String> activityJson = convert.JSON.decode(
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
        convert.JSON.decode(json);
    _contextualWifiNetworks = decodedJson['wifi_network'];
    _contextualLocations = decodedJson['location'];
    _contextualTimeOnly = decodedJson['time_only'];
    _contextualDateOnly = decodedJson['date_only'];
    _contextualBackgroundImages = decodedJson['background_image'];
    notifyListeners();
  }

  /// The list of topics this model wants updates on.
  static List<String> get topics => _kTopics;
}
