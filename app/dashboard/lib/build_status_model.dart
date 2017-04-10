// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:lib.widgets/modular.dart';

/// Indicates the last known status of a particular build.
enum BuildStatus {
  /// The build status hasn't been determined yet.
  unknown,

  /// A network error occurred getting the build status.
  networkError,

  /// A parse error occurred while determining the build status.
  parseError,

  /// The build was successful.
  success,

  /// The build failed.
  failure,
}

/// Manages a build status and associated metadata.
class BuildStatusModel extends ModuleModel {
  /// The build type.
  final String type;

  /// The build name.
  final String name;

  /// The url of the page used to determine the build status.
  final String url;

  DateTime _lastRefreshed;
  DateTime _lastRefreshStarted;
  DateTime _lastRefreshEnded;
  BuildStatus _buildStatus = BuildStatus.unknown;
  String _errorMessage;

  /// Constructor.
  BuildStatusModel({this.type, this.name, this.url});

  /// Returns the time when the status was refreshed.
  DateTime get lastRefreshed => _lastRefreshed;

  /// Returns the time when the status is starting to refresh.
  DateTime get lastRefreshStarted => _lastRefreshStarted;

  /// Returns the time when the status is finished refreshing.
  DateTime get lastRefreshEnded => _lastRefreshEnded;

  /// Returns the current build status.
  BuildStatus get buildStatus => _buildStatus;

  /// If the build status isn't [BuildStatus.success] this will indicate any
  /// additional information about why not.
  String get errorMessage => _errorMessage;

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
    _lastRefreshed = new DateTime.now().toLocal();
    _fetchConfigStatus();
    notifyListeners();
  }

  Future<Null> _fetchConfigStatus() async {
    BuildStatus status = BuildStatus.parseError;
    String html;
    String errorMessage;
    _lastRefreshStarted = new DateTime.now();
    _lastRefreshEnded = null;

    try {
      http.Response response = await http.get(url);
      html = response.body;
      if (html == null) {
        errorMessage =
            'Status ${response.statusCode}\n${response.reasonPhrase}';
      }
    } catch (error) {
      status = BuildStatus.networkError;
      errorMessage = 'Error receiving response:\n$error';
    }
    _lastRefreshEnded = new DateTime.now();

    if (html == null) {
      status = BuildStatus.networkError;
    } else {
      dom.Document domTree = parse(html);
      List<dom.Element> trs = domTree.querySelectorAll('tr');
      for (dom.Element tr in trs) {
        if (tr.className == "danger") {
          status = BuildStatus.failure;
          break;
        } else if (tr.className == "success") {
          status = BuildStatus.success;
          break;
        }
      }
    }

    _buildStatus = status;
    _errorMessage = errorMessage;
    notifyListeners();
  }
}
