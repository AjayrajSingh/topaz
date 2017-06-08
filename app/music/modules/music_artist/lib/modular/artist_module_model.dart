// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:application.services/service_provider.fidl.dart';
import 'package:apps.maxwell.lib.dart/decomposition.dart';
import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:apps.modular.services.agent.agent_controller/agent_controller.fidl.dart';
import 'package:apps.modular.services.component/component_context.fidl.dart';
import 'package:apps.modular.services.module/module_context.fidl.dart';
import 'package:apps.modular.services.module/module_controller.fidl.dart';
import 'package:apps.modular.services.story/link.fidl.dart';
import 'package:apps.modules.music.services.player/player.fidl.dart'
    as player_fidl;
import 'package:apps.modules.music.services.player/track.fidl.dart'
    as track_fidl;
import 'package:apps.mozart.lib.flutter/child_view.dart';
import 'package:apps.mozart.services.views/view_token.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';

const String _kPlayerUrl = 'file:///system/apps/music_playback_agent';

const String _kPlaybackModuleUrl = 'file:///system/apps/music_playback';

/// The context topic for "focal entities"
const String _kFocalEntitiesTopic = 'focal_entities';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// [ModuleModel] that manages the state of the Artist Module.
class ArtistModuleModel extends ModuleModel {
  /// Constructor
  ArtistModuleModel({
    @required this.clientId,
    @required this.clientSecret,
  }) {
    assert(clientId != null);
    assert(clientSecret != null);
  }

  /// The artist for this given module
  Artist artist;

  /// Albums for the given artist
  List<Album> albums;

  /// List of relatedArtists for the given artist
  List<Artist> relatedArtists;

  /// Spotify API client ID
  final String clientId;

  /// Spotify API client escret
  final String clientSecret;

  LoadingStatus _loadingStatus = LoadingStatus.inProgress;

  /// Get the current loading status
  LoadingStatus get loadingStatus => _loadingStatus;

  /// Child View Connection for the Playback Module
  ChildViewConnection _playbackViewConn;

  /// Getter for the Playback Module child view connection
  ChildViewConnection get playbackViewConn => _playbackViewConn;

  final AgentControllerProxy _playbackAgentController =
      new AgentControllerProxy();

  final player_fidl.PlayerProxy _player = new player_fidl.PlayerProxy();

  /// Retrieves all the data necessary to render the artist module
  Future<Null> fetchArtist(String artistId) async {
    try {
      Api api = new Api(
        clientId: clientId,
        clientSecret: clientSecret,
      );
      List<dynamic> response = await Future.wait(<Future<Object>>[
        api.getArtistById(artistId),
        api.getAlbumsForArtist(artistId),
        api.getRelatedArtists(artistId),
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

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
    ServiceProvider incomingServices,
  ) {
    super.onReady(moduleContext, link, incomingServices);

    // Obtain the component context.
    ComponentContextProxy componentContext = new ComponentContextProxy();
    moduleContext.getComponentContext(componentContext.ctrl.request());

    // Obtain the Player service
    ServiceProviderProxy playerServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kPlayerUrl,
      playerServices.ctrl.request(),
      _playbackAgentController.ctrl.request(),
    );
    connectToService(playerServices, _player.ctrl);

    _startPlaybackModule();

    // Close all the unnecessary bindings.
    playerServices.ctrl.close();
    componentContext.ctrl.close();
  }

  @override
  Future<Null> onStop() async {
    _player.ctrl.close();
    _playbackAgentController.ctrl.close();
    super.onStop();
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
        _kFocalEntitiesTopic,
        JSON.encode(
          <String, String>{
            '@type': _kMusicArtistType,
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

  /// Plays the given track
  void playTrack(Track track, Album album) {
    if (track.playbackUrl != null) {
      track_fidl.Track trackFidl = new track_fidl.Track()
        ..title = track.name
        ..id = track.id
        ..artist = track.artists.first?.name
        ..album = album.name
        ..cover = album.defaultArtworkUrl
        ..playbackUrl = track.playbackUrl
        ..durationInSeconds = track.duration.inSeconds;
      _player.play(trackFidl);
    }
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
        null,
      );
    }
  }

  /// Starts the embedded Playback Module
  void _startPlaybackModule() {
    InterfacePair<ViewOwner> viewOwner = new InterfacePair<ViewOwner>();
    moduleContext.startModule(
      'Music Playback',
      _kPlaybackModuleUrl,
      '',
      null,
      null,
      new InterfacePair<ModuleController>().passRequest(),
      viewOwner.passRequest(),
    );
    _playbackViewConn = new ChildViewConnection(viewOwner.passHandle());
    notifyListeners();
  }
}
