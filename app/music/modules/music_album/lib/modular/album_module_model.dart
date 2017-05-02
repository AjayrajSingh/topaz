// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.widgets/modular.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';

/// [ModuleModel] that manages the state of the Album Module.
class AlbumModuleModel extends ModuleModel {
  /// The album for this given module
  Album album;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves the full album based on the given ID
  Future<Null> fetchAlbum(String albumId) async {
    try {
      album = await Api.getAlbumById(albumId);
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
      albumId = Uri.parse(doc['view']['uri']).pathSegments[0];
    } catch (_) {
      return;
    }

    fetchAlbum(albumId);
  }
}
