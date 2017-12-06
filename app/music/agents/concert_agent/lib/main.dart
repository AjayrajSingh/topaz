// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:lib.app.dart/app.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.decomposition.dart/decomposition.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.suggestion.fidl/proposal.fidl.dart';
import 'package:lib.suggestion.fidl/proposal_publisher.fidl.dart';
import 'package:lib.suggestion.fidl/suggestion_display.fidl.dart';

/// The Concert Agents subscribes to the hotel topic and makes proposals for
/// upcoming concerts (concert list module).

const String _kHotelTopic = 'link/hotel';

/// Global scoping to prevent garbage collection
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListener listens to hotel reservations and makes a concert
/// list proposal
class ContextListenerImpl extends ContextListener {
  final ContextListenerBinding _binding = new ContextListenerBinding();

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListener> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onContextUpdate(ContextUpdate result) async {
    if (result.values[_kHotelTopic].isEmpty) {
      return;
    }

    // TODO(thatguy): There can be more than one value. At some point, use the
    // entity type in the ContextQuery instead of using topics as if they are
    // types, and handle multiple instances.
    dynamic data = JSON.decode(result.values[_kHotelTopic][0].content);
    if (data != null && data['name'] is String) {
      _createProposal(data['name']);
    }
  }

  /// Creates a concert list proposal
  void _createProposal(String hotelName) {
    String headline = 'Upcoming concerts near $hotelName this week';

    final Uri arg = new Uri(
      host: 'www.songkick.com',
      pathSegments: <String>['metro_areas', '26330-us-sf-bay-area'],
    );

    Proposal proposal = new Proposal(
        id: 'Concerts Near Hotel',
        display: new SuggestionDisplay(
            headline: headline,
            subheadline: 'powered by Songkick',
            details: '',
            color: 0xFF467187,
            iconUrls: const <String>[],
            imageType: SuggestionImageType.other,
            imageUrl:
                'https://images.unsplash.com/photo-1486591978090-58e619d37fe7?dpr=1&auto=format&fit=crop&w=300&h=300&q=80&cs=tinysrgb&crop=&bg=',
            annoyance: AnnoyanceType.none),
        onSelected: <Action>[
          new Action.withCreateStory(new CreateStory(
              moduleId: 'concert_event_list',
              initialData:
                  JSON.encode(<String, dynamic>{'view': decomposeUri(arg)})))
        ]);

    log.fine('proposing concert suggestion');
    _proposalPublisher.propose(proposal);
  }
}

Future<Null> main(List<dynamic> args) async {
  setupLogger();

  connectToService(_context.environmentServices, _contextReader.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQuery query =
      const ContextQuery(selector: const <String, ContextSelector>{
    _kHotelTopic: const ContextSelector(
        type: ContextValueType.entity,
        meta: const ContextMetadata(
            entity: const EntityMetadata(topic: _kHotelTopic)))
  });
  _contextListenerImpl = new ContextListenerImpl();
  _contextReader.subscribe(query, _contextListenerImpl.getHandle());
}
