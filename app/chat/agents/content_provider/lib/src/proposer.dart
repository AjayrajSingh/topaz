// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;

import 'package:apps.maxwell.services.context/context_provider.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.modules.chat.services/chat_content_provider.fidl.dart';

const List<String> _kHomeContacts = const <String>[];
const List<String> _kWorkContacts = const <String>[];

void _log(String msg) {
  print('[chat_content_provider] [Proposer] $msg');
}

/// Proposes suggestions when new messages come in based on the current context.
class Proposer extends ContextListener {
  /// Publishes proposals.
  final ProposalPublisher proposalPublisher;
  String _currentLocation = 'unknown';
  List<String> _visibleStories = <String>[];

  /// Constructor.
  Proposer({this.proposalPublisher});

  /// Called when a message is received.
  void onMessageReceived(Conversation conversation, Message message) {
    // TODO(apwilson): Map conversations to stories and only make proposals
    // if the story the conversation is a part of isn't visible.
    if (_currentLocation == 'work' && _kWorkContacts.contains(message.sender)) {
      _log('Sending interruptive suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, true));
    } else if (_currentLocation == 'home' &&
        _kHomeContacts.contains(message.sender)) {
      _log('Sending interruptive suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, true));
    } else {
      _log('Sending normal suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, false));
    }
  }

  @override
  void onUpdate(ContextUpdate result) {
    _log('onUpdate: ${result.values}');
    _currentLocation = result.values['/location/home_work'] ?? 'unknown';
    if (result.values.keys.contains('/story/visible_ids')) {
      _visibleStories = JSON.decode(result.values['/story/visible_ids']);
    } else {
      _visibleStories = <String>[];
    }
    _log('Current location: $_currentLocation');
    _log('Visible stories: $_visibleStories');
  }

  Proposal _createProposal(Message message, bool interruptive) => new Proposal()
    ..id = 'Message from ${message.sender}'
    ..display = (new SuggestionDisplay()
      ..headline = 'Message from ${message.sender}'
      ..subheadline = ''
      ..details = ''
      ..color = 0xFFFF0080
      ..iconUrls = const <String>[]
      ..imageType = SuggestionImageType.other
      ..imageUrl = '')
    ..onSelected = <Action>[
      new Action()..focusStory = (new FocusStory()..storyId = '')
    ];
}
