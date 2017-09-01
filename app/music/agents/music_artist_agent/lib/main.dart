// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.lib.dart/decomposition.dart';
import 'package:apps.maxwell.services.context/context_reader.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:config/config.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:music_api/api.dart';
import 'package:music_models/music_models.dart';

/// The Music Artist Agent subscribes to the 'focal_entities' topic and will
/// propose Music Artist suggestions if any of those Entities is an artist that
/// Spotify recognizes

/// The context topic for "Music Artist"
const String _kMusicArtistTopic = '/story/focused/explicit/music_artist';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// Global scoping to prevent garbage collection
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerForTopicsImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListenerForTopics that prints if the given artist has an upcoming
/// concert in the user's metro area.
class ContextListenerForTopicsImpl extends ContextListenerForTopics {
  final ContextListenerForTopicsBinding _binding =
      new ContextListenerForTopicsBinding();

  Api _api;

  /// Constructor
  ContextListenerForTopicsImpl({
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
  InterfaceHandle<ContextListenerForTopics> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onUpdate(ContextUpdateForTopics result) async {
    if (!result.values.containsKey(_kMusicArtistTopic)) {
      return;
    }

    List<dynamic> data = JSON.decode(result.values[_kMusicArtistTopic]);
    for (dynamic entity in data) {
      try {
        if (!(entity is Map<String, dynamic>)) continue;
        if (entity.containsKey('@type') &&
            entity['@type'] == _kMusicArtistType) {
          log.fine('artist update: ${entity['name']}');
          List<Artist> artists = await _api.searchArtists(
            entity['name'],
          );
          if (artists != null && artists.length > 0) {
            log.fine('found artist for: ${entity['name']}');
            _createProposal(artists.first);
          } else {
            log.fine('no artist found for: ${entity['name']}');
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

    log.fine('proposing artist suggestion');
    _proposalPublisher.propose(proposal);
  }
}

Future<Null> main(List<dynamic> args) async {
  setupLogger();

  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['spotify_client_id', 'spotify_client_secret']);
  connectToService(_context.environmentServices, _contextReader.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQueryForTopics query = new ContextQueryForTopics()
    ..topics = <String>[_kMusicArtistTopic];
  _contextListenerImpl = new ContextListenerForTopicsImpl(
    clientId: config.get('spotify_client_id'),
    clientSecret: config.get('spotify_client_secret'),
  );
  _contextReader.subscribeToTopics(query, _contextListenerImpl.getHandle());
}
