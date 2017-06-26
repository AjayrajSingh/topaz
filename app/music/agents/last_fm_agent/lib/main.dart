// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.context/context_provider.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.modular.services.surface/surface.fidl.dart';
import 'package:config/config.dart';
import 'package:last_fm_api/api.dart';
import 'package:last_fm_models/last_fm_models.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:meta/meta.dart';

/// The Music Artist Agent subscribes to the 'focal_entities' topic and will
/// propose Music Artist suggestions if any of those Entities is an artist that
/// Spotify recognizes

/// The context topic for "focal entities" for the current story.
const String _kCurrentFocalEntitiesTopic = 'focal_entities';

/// The Entity type for a music artist.
const String _kMusicArtistType = 'http://types.fuchsia.io/music/artist';

/// Global scoping to prevent garbage collection
final ContextProviderProxy _contextProvider = new ContextProviderProxy();
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
      : _api = new LastFmApi(apiKey: apiKey) {
    assert(apiKey != null);
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

    dynamic data = JSON.decode(result.values[_kCurrentFocalEntitiesTopic]);

    if (_isValidArtistContextLink(data)) {
      log.fine('artist update: ${data['name']}');
      try {
        Artist artist = await _api.getArtist(data['name']);
        if (artist != null) {
          log.fine('found artist for: ${data['name']}');
          _createProposal(artist, data);
        } else {
          log.fine('no artist found for: ${data['name']}');
        }
      } catch (_) {}
    }
  }

  /// Creates a proposal for the given Last FM artist
  void _createProposal(Artist artist, Map<String, dynamic> data) {
    String headline = 'Learn more about ${artist.name}';

    Proposal proposal = new Proposal()
      ..id = 'Last FM Artist bio: ${artist.mbid}'
      ..display = (new SuggestionDisplay()
        ..headline = headline
        ..subheadline = 'powered by Last.fm'
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl = artist.imageUrl
        ..annoyance = AnnoyanceType.none)
      ..onSelected = <Action>[
        new Action()
          ..addModuleToStory = (new AddModuleToStory()
            ..linkName = data['@source']['link_name']
            ..storyId = data['@source']['story_id']
            ..moduleName = 'Last FM: ${data['name']}'
            ..modulePath = data['@source']['module_path']
            ..moduleUrl = 'file:///system/apps/last_fm_artist_bio'
            ..surfaceRelation = (new SurfaceRelation()
              ..arrangement = SurfaceArrangement.copresent
              ..emphasis = 0.5
              ..dependency = SurfaceDependency.dependent))
      ];

    log.fine('proposing artist bio suggestion');
    _proposalPublisher.propose(proposal);
  }

  /// A valid artist context link must satisfy the following criteria:
  /// * @type must be 'http://types.fuchsia.io/music/artist'.
  /// * Must have a @source field which contains the story ID, link name and
  ///   module path.
  /// * Must specify a name
  bool _isValidArtistContextLink(Map<String, dynamic> data) {
    return data['@type'] is String &&
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

  Config config = await Config.read('/system/data/modules/config.json');
  config.validate(<String>['last_fm_api_key']);
  connectToService(_context.environmentServices, _contextProvider.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQuery query = new ContextQuery.init(
      <String>[_kCurrentFocalEntitiesTopic], null /* filters */);
  _contextListenerImpl = new ContextListenerImpl(
    apiKey: config.get('last_fm_api_key'),
  );
  _contextProvider.subscribe(query, _contextListenerImpl.getHandle());
}
