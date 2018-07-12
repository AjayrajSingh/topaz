// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lib.widgets.dart/model.dart';

import 'enums.dart';
import 'service/build_info.dart';
import 'service/build_service.dart';

final DateTime _kHalloween = new DateTime.utc(
  2018,
  10,
  31,
  12,
);

/// Manages a build status and associated metadata.
class BuildStatusModel extends Model {
  /// The build type.
  final String type;

  /// The build name.
  final String name;

  /// The url of the page used to determine the build status.
  final String url;

  /// The service used to fetch [BuildInfo].
  final BuildService _buildService;
  StreamSubscription<BuildInfo> _pendingRequest;

  DateTime _lastRefreshed;
  DateTime _lastRefreshStarted;
  DateTime _lastRefreshEnded;
  DateTime _lastFailTime;
  DateTime _lastPassTime;
  BuildResultEnum _buildResult;
  String _errorMessage;

  /// Constructor.
  BuildStatusModel({this.type, this.name, this.url, BuildService buildService})
      : _buildService = buildService;

  /// Returns the time when the status was refreshed.
  DateTime get lastRefreshed => _lastRefreshed;

  /// Returns the time when the status is starting to refresh.
  DateTime get lastRefreshStarted => _lastRefreshStarted;

  /// Returns the time when the status is finished refreshing.
  DateTime get lastRefreshEnded => _lastRefreshEnded;

  /// Returns the current build status.
  BuildResultEnum get buildResult => _buildResult;

  /// The time the build started failing.
  DateTime get lastFailTime => _lastFailTime;

  /// The time the build started passing.
  DateTime get lastPassTime => _lastPassTime;

  /// If the build status isn't [BuildResultEnum.success.value] this will
  /// indicate any additional information about why not.
  String get errorMessage => _errorMessage;

  /// The color to use as the background of a successful build.
  /// The default success color was chosen from
  /// http://www.visualisingdata.com/2015/11/colour-swatch-alternatives-to-green-and-red/
  /// to allow it to be more easily seen by those with color blindness.
  Color get successColor {
    Duration difference = new DateTime.now().difference(_kHalloween).abs();
    if (difference < const Duration(days: 1)) {
      return Colors.orange[700];
    }
    return new Color(0xFF4DAC26);
  }

  /// The color to use as the background of a failed build.
  /// The default success color was chosen from
  /// http://www.visualisingdata.com/2015/11/colour-swatch-alternatives-to-green-and-red/
  /// to allow it to be more easily seen by those with color blindness.
  Color get failColor {
    Duration difference = new DateTime.now().difference(_kHalloween).abs();
    if (difference < const Duration(days: 1)) {
      return Colors.black;
    }
    return new Color(0xFFD01C8B);
  }

  /// Starts the model refreshing periodically.
  void start() {
    new Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
    refresh();
  }

  /// Initiates a refresh of the build status.
  void refresh() {
    _fetchConfigStatus();
    notifyListeners();
  }

  Future<Null> _fetchConfigStatus() async {
    await _pendingRequest?.cancel();
    _lastRefreshStarted = new DateTime.now();
    _lastRefreshEnded = null;

    runZoned(() {
      _pendingRequest =
          _buildService.getBuildByName(url).listen((BuildInfo response) {
        _pendingRequest?.cancel();
        _pendingRequest = null;
        _errorMessage = null;
        _buildResult = response.result;
        _handleFetchComplete();
      });
    }, onError: (Object error) {
      _pendingRequest?.cancel();
      _pendingRequest = null;
      _buildResult = null;
      _errorMessage = 'Error: $error';
      _handleFetchComplete();

      if (error is TimeoutException) {
        _errorMessage = '$_errorMessage  Retrying...';
        refresh();
      }
    });
  }

  void _handleFetchComplete() {
    _lastRefreshEnded = new DateTime.now();
    if (_buildResult == BuildResultEnum.success) {
      if (_lastPassTime == null) {
        _lastPassTime = new DateTime.now();
        _lastFailTime = null;
      }
    } else {
      if (_lastFailTime == null) {
        _lastFailTime = new DateTime.now();
        _lastPassTime = null;
      }
    }
    notifyListeners();
  }
}
