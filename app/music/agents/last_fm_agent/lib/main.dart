// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:config/config.dart';
import 'package:last_fm_api/api.dart';
import 'package:last_fm_models/last_fm_models.dart';
import 'package:lib.app.dart/app.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:fidl/fidl.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.proposal.dart/proposal.dart';
import 'package:meta/meta.dart';

/// The Music Artist Agent subscribes to the 'focal_entities' topic and will
/// propose Music Artist suggestions if any of those Entities is an artist that
/// Spotify recognizes

/// The context topic for "Music Artist"
const String _kMusicArtistTopic = 'link/music_artist';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// Global scoping to prevent garbage collection
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListener that prints if the given artist has an upcoming
/// concert in the user's metro area.
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();

  final LastFmApi _api;

  /// Constructor
  ContextListenerImpl({
    @required String apiKey,
  })
      : assert(apiKey != null),
        _api = new LastFmApi(apiKey: apiKey);

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onContextUpdate(ContextUpdate result) async {
    for (final ContextUpdateEntry entry in result.values) {
      if (entry.key != _kMusicArtistTopic || entry.value.isEmpty) {
        continue;
      }

      // TODO(thatguy): There can be more than one value. At some point, use the
      // entity type in the ContextQuery instead of using topics as if they are
      // types, and handle multiple instances.
      dynamic data = json.decode(entry.value[0].content);

      if (_isValidArtistContextLink(data)) {
        log.fine('artist update: ${data['name']}');
        try {
          Artist artist = await _api.getArtist(data['name']);
          if (artist != null) {
            log.fine('found artist for: ${data['name']}');
            await _createProposal(artist, data);
          } else {
            log.fine('no artist found for: ${data['name']}');
          }
        } on Exception {
          return;
        }
      }
    }
  }

  /// Creates a proposal for the given Last FM artist
  Future<Null> _createProposal(Artist artist, Map<String, dynamic> data) async {
    String headline = 'Learn more about ${artist.name}';

    Proposal proposal = await createProposal(
      id: 'Last FM Artist bio: ${artist.mbid}',
      headline: headline,
      subheadline: 'powered by Last.fm',
      color: 0xFFFF0080,
      imageUrl: artist.imageUrl,
      actions: <Action>[
        new Action.withAddModuleToStory(new AddModuleToStory(
            linkName: data['@source']['link_name'],
            storyId: data['@source']['story_id'],
            moduleName: 'Last FM: ${data['name']}',
            modulePath: data['@source']['module_path'],
            moduleUrl: 'last_fm_artist_bio',
            surfaceRelation: new SurfaceRelation(
                arrangement: SurfaceArrangement.copresent,
                emphasis: 0.5,
                dependency: SurfaceDependency.dependent)))
      ],
    );

    log.fine('proposing artist bio suggestion');
    _proposalPublisher.propose(proposal);
  }

  /// A valid artist context link must satisfy the following criteria:
  /// * @type must be 'http://types.fuchsia.io/music/artist'.
  /// * Must have a @source field which contains the story ID, link name and
  ///   module path.
  /// * Must specify a name
  bool _isValidArtistContextLink(Map<String, dynamic> data) {
    return data != null &&
        data['@type'] is String &&
        data['@type'] == _kMusicArtistType &&
        data['@source'] is Map<String, dynamic> &&
        data['@source']['story_id'] is String &&
        data['@source']['link_name'] is String &&
        data['@source']['module_path'] is List<String> &&
        data['name'] is String;
  }
}

Future<Null> main(List<dynamic> args) async {
  setupLogger();

  Config config = await Config.read('/system/data/modules/config.json')
    ..validate(<String>['last_fm_api_key']);
  connectToService(_context.environmentServices, _contextReader.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQuery query =
      const ContextQuery(selector: const <ContextQueryEntry>[const
        ContextQueryEntry(
    key: _kMusicArtistTopic, value: const ContextSelector(
        type: ContextValueType.entity,
        meta: const ContextMetadata(
            entity: const EntityMetadata(topic: _kMusicArtistTopic)))
  )]);
  _contextListenerImpl = new ContextListenerImpl(
    apiKey: config.get('last_fm_api_key'),
  );
  _contextReader.subscribe(query, _contextListenerImpl.getHandle());
}
