// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.context/context_reader.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';

/// The Concert Agents subscribes to the hotel topic and makes proposals for
/// upcoming concerts (concert list module).

const String _kHotelTopic = '/story/focused/link/hotel';

/// Global scoping to prevent garbage collection
final ContextReaderProxy _contextReader = new ContextReaderProxy();
ContextListenerForTopicsImpl _contextListenerImpl;
final ProposalPublisherProxy _proposalPublisher = new ProposalPublisherProxy();
final ApplicationContext _context = new ApplicationContext.fromStartupInfo();

/// Concert ContextListenerForTopics listens to hotel reservations and makes a concert
/// list proposal
class ContextListenerForTopicsImpl extends ContextListenerForTopics {
  final ContextListenerForTopicsBinding _binding = new ContextListenerForTopicsBinding();

  /// Gets the [InterfaceHandle]
  ///
  /// The returned handle should only be used once.
  InterfaceHandle<ContextListenerForTopics> getHandle() => _binding.wrap(this);

  @override
  Future<Null> onUpdate(ContextUpdateForTopics result) async {
    if (!result.values.containsKey(_kHotelTopic)) {
      return;
    }

    dynamic data = JSON.decode(result.values[_kHotelTopic]);
    if (data != null && data['name'] is String) {
      _createProposal(data['name']);
    }
  }

  /// Creates a concert list proposal
  void _createProposal(String hotelName) {
    String headline = 'Upcoming concerts near $hotelName this week';

    Proposal proposal = new Proposal()
      ..id = 'Concerts Near Hotel'
      ..display = (new SuggestionDisplay()
        ..headline = headline
        ..subheadline = 'powered by Songkick'
        ..details = ''
        ..color = 0xFF467187
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl =
            'https://images.unsplash.com/photo-1486591978090-58e619d37fe7?dpr=1&auto=format&fit=crop&w=300&h=300&q=80&cs=tinysrgb&crop=&bg='
        ..annoyance = AnnoyanceType.none)
      ..onSelected = <Action>[
        new Action()
          ..createStory = (new CreateStory()
            ..moduleId = 'file:///system/apps/concert_event_list')
      ];

    log.fine('proposing concert suggestion');
    _proposalPublisher.propose(proposal);
  }
}

Future<Null> main(List<dynamic> args) async {
  setupLogger();

  connectToService(_context.environmentServices, _contextReader.ctrl);
  connectToService(_context.environmentServices, _proposalPublisher.ctrl);
  ContextQueryForTopics query = new ContextQueryForTopics()
      ..topics = <String>[_kHotelTopic];
  _contextListenerImpl = new ContextListenerForTopicsImpl();
  _contextReader.subscribeToTopics(query, _contextListenerImpl.getHandle());
}
