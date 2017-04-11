// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.widgets/modular.dart';

import 'api/api.dart';
import 'models/album.dart';
import 'widgets/loading_status.dart';

/// [ModuleModel] that manages the state of the
/// AlbumSurface.
class AlbumSurfaceModel extends ModuleModel {
  /// ID of the album for this AlbumSurface
  final String albumId;

  /// The album for this given surface
  Album album;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Constructor
  AlbumSurfaceModel({
    this.albumId,
  }) {
    assert(albumId != null);
  }

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves the full album based on the given ID
  Future<Null> fetchAlbum() async {
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
}
