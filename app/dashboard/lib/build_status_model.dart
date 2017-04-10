// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:lib.widgets/modular.dart';

enum BuildStatus { unknown, networkError, parseError, success, failure }

class BuildStatusModel extends ModuleModel {
  final String type;
  final String name;
  final String url;
  DateTime _lastRefreshed;
  DateTime _lastRefreshStarted;
  DateTime _lastRefreshEnded;
  BuildStatus _buildStatus = BuildStatus.unknown;
  String _errorMessage;

  BuildStatusModel({this.type, this.name, this.url});

  DateTime get lastRefreshed => _lastRefreshed;
  DateTime get lastRefreshStarted => _lastRefreshStarted;
  DateTime get lastRefreshEnded => _lastRefreshEnded;
  BuildStatus get buildStatus => _buildStatus;
  String get errorMessage => _errorMessage;

  void start() {
    new Timer.periodic(
      const Duration(seconds: 60),
      (_) => refresh(),
    );
    refresh();
  }

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
