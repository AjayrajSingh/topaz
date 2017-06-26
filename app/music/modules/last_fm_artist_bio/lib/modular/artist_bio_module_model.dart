// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:last_fm_api/api.dart';
import 'package:last_fm_models/last_fm_models.dart';
import 'package:last_fm_widgets/last_fm_widgets.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';

/// [ModuleModel] that manages the state of the Artist Bio Module.
class ArtistBioModuleModel extends ModuleModel {
  /// Constructor
  ArtistBioModuleModel({
    @required this.apiKey,
  })
      : _api = new LastFmApi(apiKey: apiKey) {
    assert(apiKey != null);
  }

  /// The artist for this given module
  Artist artist;

  /// Last FM API key
  final String apiKey;

  final LastFmApi _api;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;
  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Retrieves the artist bio
  Future<Null> fetchArtist(String name) async {
    try {
      artist = await _api.getArtist(name);
      if (artist != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (error) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Look for the artist name in the link and update
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    if (doc is Map && doc['name'] is String) {
      fetchArtist(doc['name']);
    }
  }
}
