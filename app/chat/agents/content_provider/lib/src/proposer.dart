// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show JSON;
import 'dart:io';

import 'package:apps.maxwell.services.context/context_provider.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.modules.chat.services/chat_content_provider.fidl.dart';

const String _kContactsJsonFile = '/system/data/modules/contacts.json';

void _log(String msg) {
  print('[chat_content_provider] [Proposer] $msg');
}

/// Proposes suggestions when new messages come in based on the current context.
class Proposer extends ContextListener {
  /// Publishes proposals.
  final ProposalPublisher proposalPublisher;
  final List<String> _homeContacts = <String>[];
  final List<String> _workContacts = <String>[];
  String _currentLocation = 'unknown';
  List<String> _visibleStories = <String>[];

  /// Constructor.
  Proposer({this.proposalPublisher});

  /// Loads the contacts configuration used to make proposals.
  void load() {
    String json = new File(_kContactsJsonFile).readAsStringSync();
    final List<Map<String, dynamic>> decodedJson = JSON.decode(json);
    decodedJson.forEach((Map<String, dynamic> contact) {
      List<String> context = contact['context'] ?? <String>[];
      String email = contact['email'];
      if (email == null) {
        return;
      }
      if (context.contains('work')) {
        _workContacts.add(email);
      }
      if (context.contains('home')) {
        _homeContacts.add(email);
      }
    });
  }

  /// Called when a message is received.
  void onMessageReceived(Conversation conversation, Message message) {
    // TODO(apwilson): Map conversations to stories and only make proposals
    // if the story the conversation is a part of isn't visible.
    if (_currentLocation == 'work' && _workContacts.contains(message.sender)) {
      _log('Sending interruptive suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, true));
    } else if (_currentLocation == 'home' &&
        _homeContacts.contains(message.sender)) {
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
      ..imageUrl = ''
      ..annoyance = AnnoyanceType.none)
    ..onSelected = <Action>[
      new Action()..focusStory = (new FocusStory()..storyId = '')
    ];
}
