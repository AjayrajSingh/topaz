// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:concert_widgets/concert_widgets.dart';
import 'package:lib.widgets/modular.dart';

/// [ModuleModel] that manages the state of the Event Module.
class EventModuleModel extends ModuleModel {
  /// The event for this given module
  Event _event;

  /// API key for Songkick APIs
  final String apiKey;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Constructor
  EventModuleModel({this.apiKey}) : super();

  /// Get the event
  Event get event => _event;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves the full event based on the given ID
  Future<Null> fetchEvent(int eventId) async {
    try {
      _event = await Api.getEvent(eventId, apiKey);
      if (_event != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Update the event ID
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['songkick:eventId'] is int) {
      fetchEvent(doc['songkick:eventId']);
    }
  }
}
