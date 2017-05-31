// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';

/// [ModuleModel] that manages the state of the Album Module.
class AlbumModuleModel extends ModuleModel {
  /// The album for this given module
  Album album;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Spotify API client ID
  final String clientId;

  /// Spotify API client escret
  final String clientSecret;

  /// Constructor
  AlbumModuleModel({
    @required this.clientId,
    @required this.clientSecret,
  }) {
    assert(clientId != null);
    assert(clientSecret != null);
  }

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves the full album based on the given ID
  Future<Null> fetchAlbum(String albumId) async {
    Api api = new Api(
      clientId: clientId,
      clientSecret: clientSecret,
    );
    try {
      album = await api.getAlbumById(albumId);
      if (album != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (error) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Update the album ID
  @override
  void onNotify(String json) {
    final dynamic doc = JSON.decode(json);
    String albumId;

    try {
      final dynamic uri = doc['view'];
      if (uri['scheme'] == 'spotify' && uri['host'] == 'album') {
        albumId = uri['path segments'][0];
      } else if (uri['path segments'][0] == 'album') {
        albumId = uri['path segments'][1];
      } else {
        return;
      }
    } catch (_) {
      return;
    }

    fetchAlbum(albumId);
  }
}
