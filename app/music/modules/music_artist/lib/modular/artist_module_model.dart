// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.component.fidl/component_context.fidl.dart';
import 'package:lib.decomposition.dart/decomposition.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.module.fidl/module_context.fidl.dart';
import 'package:lib.module.fidl._module_controller/module_controller.fidl.dart';
import 'package:lib.story.fidl/link.fidl.dart';
import 'package:lib.surface.fidl/surface.fidl.dart';
import 'package:lib.ui.flutter/child_view.dart';
import 'package:lib.ui.views.fidl._view_token/view_token.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:lib.widgets/modular.dart';
import 'package:meta/meta.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';
import 'package:music_widgets/music_widgets.dart';
import 'package:topaz.app.music.services.player/player.fidl.dart'
    as player_fidl;
import 'package:topaz.app.music.services.player/status.fidl.dart';
import 'package:topaz.app.music.services.player/track.fidl.dart' as track_fidl;

const String _kPlayerUrl = 'music_playback_agent';

const String _kPlaybackModuleUrl = 'music_playback';

/// The context topic for "Music Artist"
const String _kMusicArtistTopic = 'music_artist';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

const String _kArtistContextLinkName = 'artist_context';

/// [ModuleModel] that manages the state of the Artist Module.
class ArtistModuleModel extends ModuleModel {
  /// Constructor
  ArtistModuleModel({
    @required this.clientId,
    @required this.clientSecret,
  })
      : assert(clientId != null),
        assert(clientSecret != null);

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

  final LinkProxy _contextLink = new LinkProxy();

  /// The current device mode
  String get deviceMode => _deviceMode;
  String _deviceMode;

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
    } on Exception {
      _loadingStatus = LoadingStatus.failed;
    }

    // Set the first track of the first album for playback if there is no track
    // in the playback queue.
    _player.getStatus((PlayerStatus playerStatus) {
      if (albums.isNotEmpty && albums.first.tracks.isNotEmpty) {
        track_fidl.Track firstTrack = _convertTrackToFidl(
          albums.first.tracks.first,
          albums.first,
        );
        // play first track if in edgeToEdge mode
        if (deviceMode == 'edgeToEdge') {
          _player.play(firstTrack);
        } else if (playerStatus.track == null) {
          _player.setTrack(firstTrack);
        }
      }
    });

    notifyListeners();
  }

  @override
  void onReady(
    ModuleContext moduleContext,
    Link link,
  ) {
    super.onReady(moduleContext, link);

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

    // Setup the Context Link
    moduleContext.getLink(_kArtistContextLinkName, _contextLink.ctrl.request());

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
  Future<Null> onNotify(String encoded) async {
    final dynamic doc = json.decode(encoded);
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
    } on Exception {
      return;
    }

    await fetchArtist(artistId);

    if (artist != null) {
      // Publish artist data as 'context link'
      Map<String, dynamic> contextLinkData = <String, dynamic>{
        '@context': <String, dynamic>{
          'topic': _kMusicArtistTopic,
        },
        '@type': _kMusicArtistType,
        'name': artist.name,
        'spotifyId': artist.id,
      };
      _contextLink.set(null, json.encode(contextLinkData));
    }
  }

  @override
  void onDeviceMapChange(DeviceMapEntry entry) {
    Map<String, dynamic> profileMap = json.decode(entry.profile);
    if (_deviceMode != profileMap['mode']) {
      _deviceMode = profileMap['mode'];
      notifyListeners();
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
      url: 'music_artist',
      initialData: json.encode(<String, dynamic>{'view': decomposeUri(arg)}),
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
      url: 'music_album',
      initialData: json.encode(<String, dynamic>{'view': decomposeUri(arg)}),
    );
  }

  /// Plays the given track
  void playTrack(Track track, Album album) {
    if (track.playbackUrl != null) {
      track_fidl.Track trackFidl = _convertTrackToFidl(track, album);
      _player.play(trackFidl);
    }
  }

  track_fidl.Track _convertTrackToFidl(Track track, Album album) {
    return new track_fidl.Track(
        title: track.name,
        id: track.id,
        artist: track.artists.first?.name,
        album: album.name,
        cover: album.defaultArtworkUrl,
        playbackUrl: track.playbackUrl,
        durationInSeconds: track.duration.inSeconds);
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
        null, // incomingServices,
        new InterfacePair<ModuleController>().passRequest(),
        const SurfaceRelation(arrangement: SurfaceArrangement.sequential),
        true,
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
      new InterfacePair<ModuleController>().passRequest(),
      viewOwner.passRequest(),
    );
    _playbackViewConn = new ChildViewConnection(viewOwner.passHandle());
    notifyListeners();
  }
}
