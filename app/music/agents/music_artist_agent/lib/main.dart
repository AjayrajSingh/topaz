// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.lib.dart/decomposition.dart';
import 'package:apps.maxwell.services.context/context_provider.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:config/config.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:meta/meta.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';

/// The Music Artist Agent subscribes to the 'focal_entities' topic and will
/// propose Music Artist suggestions if any of those Entities is an artist that
/// Spotify recognizes

/// The context topic for "focal entities" for the current story.
const String _kCurrentFocalEntitiesTopic =
    '/story/focused/explicit/focal_entities';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

void _log(String msg) => print('[music_artist_agent] $msg');

/// Global scoping to prevent garbage collection
final ContextProviderProxy _contextProvider = new ContextProviderProxy();
ContextListenerImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListener that prints if the given artist has an upcoming
/// concert in the user's metro area.
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();

  Api _api;

  /// Constructor
  ContextListenerImpl({
    @required String clientId,
    @required String clientSecret,
  }) {
    assert(clientId != null);
    assert(clientSecret != null);
    _api = new Api(
      clientId: clientId,
      clientSecret: clientSecret,
    );
  }

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onUpdate(ContextUpdate result) async {
    if (!result.values.containsKey(_kCurrentFocalEntitiesTopic)) {
      return;
    }

    List<dynamic> data =
        JSON.decode(result.values[_kCurrentFocalEntitiesTopic]);
    for (dynamic entity in data) {
      try {
        if (!(entity is Map<String, dynamic>)) continue;
        if (entity.containsKey('@type') &&
            entity['@type'] == _kMusicArtistType) {
          _log('artist update: ${entity['name']}');
          List<Artist> artists = await _api.searchArtists(
            entity['name'],
          );
          if (artists != null && artists.length > 0) {
            _log('found artist for: ${entity['name']}');
            _createProposal(artists.first);
          } else {
            _log('no artist found for: ${entity['name']}');
          }
        }
      } catch (_) {}
    }
  }

  /// Creates a proposal for the given Spotify artist
  void _createProposal(Artist artist) {
    String headline = 'Listen to ${artist.name}';

    final Uri arg = new Uri(
      scheme: 'spotify',
      host: 'artist',
      pathSegments: <String>[artist.id],
    );

    Proposal proposal = new Proposal()
      ..id = 'Spotify Artist: ${artist.id}'
      ..display = (new SuggestionDisplay()
        ..headline = headline
        ..subheadline = 'powered by Spotify'
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl = artist.defaultArtworkUrl
        ..annoyance = AnnoyanceType.none)
      ..onSelected = <Action>[
        new Action()
          ..createStory = (new CreateStory()
            ..moduleId = 'file:///system/apps/music_artist'
            ..initialData =
                JSON.encode(<String, dynamic>{'view': decomposeUri(arg)}))
      ];

    _log('proposing artist suggestion');
    _proposalPublisher.propose(proposal);
    _proposalPublisher.ctrl.close();
  }
}

Future<Null> main(List<dynamic> args) async {
  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['spotify_client_id', 'spotify_client_secret']);

  connectToService(_context.environmentServices, _contextProvider.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQuery query =
      new ContextQuery.init(<String>[_kCurrentFocalEntitiesTopic], null);
  _contextListenerImpl = new ContextListenerImpl(
    clientId: config.get('spotify_client_id'),
    clientSecret: config.get('spotify_client_secret'),
  );
  _contextProvider.subscribe(query, _contextListenerImpl.getHandle());
}
