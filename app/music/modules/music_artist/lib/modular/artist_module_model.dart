// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:apps.maxwell.lib.dart/decomposition.dart';
import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/modular.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';

/// [ModuleModel] that manages the state of the Artist Module.
class ArtistModuleModel extends ModuleModel {
  /// The artist for this given module
  Artist artist;

  /// Albums for the given artist
  List<Album> albums;

  /// List of relatedArtists for the given artist
  List<Artist> relatedArtists;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Retrieves all the data necessary to render the artist module
  Future<Null> fetchArtist(String artistId) async {
    try {
      List<dynamic> response = await Future.wait(<Future<Object>>[
        Api.getArtistById(artistId),
        Api.getAlbumsForArtist(artistId),
        Api.getRelatedArtists(artistId),
      ]);
      artist = response[0];
      albums = response[1];
      relatedArtists = response[2];
      if (artist != null && albums != null) {
        _loadingStatus = LoadingStatus.completed;
      } else {
        _loadingStatus = LoadingStatus.failed;
      }
    } catch (_) {
      _loadingStatus = LoadingStatus.failed;
    }
    notifyListeners();
  }

  /// Update the artist ID
  @override
  Future<Null> onNotify(String json) async {
    final dynamic doc = JSON.decode(json);
    String artistId;

    try {
      final dynamic uri = doc['view'];
      if (uri['scheme'] == 'spotify' && uri['host'] == 'artist') {
        artistId = uri['path segments'][0];
      } else if (uri['path segments'][0] == 'artist') {
        artistId = uri['path segments'][1];
      } else {
        return;
      }
    } catch (_) {
      return;
    }

    await fetchArtist(artistId);

    if (artist != null) {
      // Publish artist data to Maxwell
      ContextPublisherProxy publisher = new ContextPublisherProxy();
      IntelligenceServicesProxy intelligenceServices =
          new IntelligenceServicesProxy();
      moduleContext
          .getIntelligenceServices(intelligenceServices.ctrl.request());
      intelligenceServices.getContextPublisher(publisher.ctrl.request());

      publisher.publish(
        'music/artist',
        JSON.encode(
          <String, String>{
            'name': artist.name,
            'spotifyId': artist.id,
          },
        ),
      );

      // Close all ctrls, onNotify will not be called again for the music
      // experience since a new module with a new link is launched for
      // any new view
      publisher.ctrl.close();
      intelligenceServices.ctrl.close();
    }
  }

  /// Creates a new module for the given artist
  void goToArtist(String artistId) {
    final Uri arg = new Uri(
      scheme: 'spotify',
      host: 'artist',
      pathSegments: <String>[artistId],
    );
    _startModule(
      url: 'file:///system/apps/music_artist',
      initialData: JSON.encode(<String, dynamic>{'view': decomposeUri(arg)}),
    );
  }

  /// Creates a new module for the given album
  void goToAlbum(String albumId) {
    final Uri arg = new Uri(
      scheme: 'spotify',
      host: 'album',
      pathSegments: <String>[albumId],
    );
    _startModule(
      url: 'file:///system/apps/music_album',
      initialData: JSON.encode(<String, dynamic>{'view': decomposeUri(arg)}),
    );
  }

  /// Starts a module in the story shell
  void _startModule({
    String moduleName: 'module',
    String linkName: 'link',
    String url,
    String initialData: '',
  }) {
    if (moduleContext != null) {
      LinkProxy link = new LinkProxy();
      moduleContext.getLink(linkName, link.ctrl.request());
      link
        ..set(<String>[], initialData)
        ..ctrl.close();

      moduleContext.startModuleInShell(
        moduleName,
        url,
        linkName,
        null, // outgoingServices,
        null, // incomingServices,
        new InterfacePair<ModuleController>().passRequest(),
        '',
      );
    }
  }
}
