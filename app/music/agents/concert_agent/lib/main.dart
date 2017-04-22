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
import 'package:concert_api/api.dart';
import 'package:concert_models/concert_models.dart';
import 'package:config/config.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:meta/meta.dart';

/// The Concert Agents subscribes to the 'music/artist' topic and will propose
/// event/concert suggestions if th given artist has upcoming concerts.

/// 'music/artist' topic to subscribe to
const String _kMusicArtistTopic = 'music/artist';

/// Global scoping to prevent garbage collection
ContextListenerImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListener that prints if the given artist has an upcoming
/// concert in the user's metro area.
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();

  /// Songkick API key
  final String apiKey;

  /// Constructor
  ContextListenerImpl({@required this.apiKey});

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onUpdate(ContextUpdate result) async {
    if (result.values.containsKey(_kMusicArtistTopic)) {
      Map<String, dynamic> data =
          JSON.decode(result.values[_kMusicArtistTopic]);
      if (data.containsKey('name')) {
        print('[concerts_agent] artist update: ${data['name']}');
        List<Event> events = await Api.searchEventsByArtist(
          data['name'],
          apiKey,
        );
        if (events != null && events.length > 0) {
          print('[concerts_agent] concerts found for: ${data['name']}');
          _createProposal(events, data['name']);
        } else {
          print('[concerts_agent] no concerts found for: ${data['name']}');
        }
      }
    }
  }

  /// Creates a proposal given the artist and events
  ///
  /// We need to pass in the original artist name that was used to query for
  /// upcoming coming concerts because songkick events can have more than one
  /// artist.
  ///
  /// This only creates a proposal for the top ranked event based on the
  /// search.
  void _createProposal(List<Event> events, String artistName) {
    String headline = 'Buy tickets for $artistName at ${events[0].venue.name}';

    Proposal proposal = new Proposal()
      ..id = 'Songkick Events'
      ..display = (new SuggestionDisplay()
        ..headline = headline
        ..subheadline = 'powered by Songkick'
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl = events[0].venue.imageUrl)
      ..onSelected = <Action>[
        new Action()
          ..createStory = (new CreateStory()
            // TODO (dayang@): Update once the Concert module is implemented
            // https://fuchsia.atlassian.net/browse/SO-376
            ..moduleId = 'file:///'
            ..initialData = JSON.encode(
              <String, dynamic>{'songkick:eventId': events[0].id},
            ))
      ];

    print('[concerts_agent] proposing concert suggestion');
    _proposalPublisher.propose(proposal);
    _proposalPublisher.ctrl.close();
  }
}

/// Retrieves the Songkick API Key
Future<String> _readAPIKey() async {
  Config config = await Config.read('/system/data/modules/config.json');
  String apiKey = config.get('songkick_api_key');
  if (apiKey == null) {
    print(
        '[concerts_agent] "songkick_api_key" value is not specified in config.json.');
    return null;
  } else {
    return apiKey;
  }
}

Future<Null> main(List<dynamic> args) async {
  String apiKey = await _readAPIKey();
  if (apiKey != null) {
    // final ApplicationContext context = new ApplicationContext.fromStartupInfo();
    final ContextProviderProxy contextProvider = new ContextProviderProxy();
    connectToService(_context.environmentServices, contextProvider.ctrl);
    connectToService(_context.environmentServices, _proposalPublisher.ctrl);
    ContextQuery query = new ContextQuery.init(<String>[_kMusicArtistTopic]);
    _contextListenerImpl = new ContextListenerImpl(apiKey: apiKey);
    contextProvider.subscribe(query, _contextListenerImpl.getHandle());
    contextProvider.ctrl.close();
  }
}
