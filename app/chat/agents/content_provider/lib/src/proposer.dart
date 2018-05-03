// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert' show json;
import 'dart:io';

import 'package:fuchsia.fidl.chat_content_provider/chat_content_provider.dart';
import 'package:fuchsia.fidl.modular/modular.dart';
import 'package:lib.app.dart/logging.dart';

const String _kContactsJsonFile = '/system/data/modules/contacts.json';

/// Proposes suggestions when new messages come in based on the current context.
class Proposer extends ContextListener {
  /// Publishes proposals.
  final ProposalPublisher proposalPublisher;
  final List<String> _homeContacts = <String>[];
  final List<String> _workContacts = <String>[];
  String _currentLocation = 'unknown';

  /// Constructor.
  Proposer({this.proposalPublisher});

  /// Loads the contacts configuration used to make proposals.
  void load() {
    File contactsJsonFile = new File(_kContactsJsonFile);
    if (!contactsJsonFile.existsSync()) {
      return;
    }
    String encoded = contactsJsonFile.readAsStringSync();
    final List<Map<String, dynamic>> decodedJson = json.decode(encoded);
    for (Map<String, dynamic> contact in decodedJson) {
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
    }
  }

  /// Called when a message is received.
  void onMessageReceived(Conversation conversation, Message message) {
    // TODO(apwilson): Map conversations to stories and only make proposals
    // if the story the conversation is a part of isn't visible.
    if (_currentLocation == 'work' && _workContacts.contains(message.sender)) {
      log.fine('Sending interruptive suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, true));
    } else if (_currentLocation == 'home' &&
        _homeContacts.contains(message.sender)) {
      log.fine('Sending interruptive suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, true));
    } else {
      log.fine('Sending normal suggestion for ${message.sender}');
      proposalPublisher.propose(_createProposal(message, false));
    }
  }

  @override
  void onContextUpdate(ContextUpdate result) {
    log.fine('onUpdate: ${result.values}');
    for (final ContextUpdateEntry entry in result.values) {
      if (entry.key != 'location/home_work') {
        continue;
      }

      if (entry.value.isEmpty) {
        _currentLocation = 'unknown';
      } else {
        _currentLocation = entry.value[0]?.content ?? 'unknown';
      }
      log.fine('Current location: $_currentLocation');
    }
  }

  Proposal _createProposal(Message message, bool interruptive) => new Proposal(
          id: 'Message from ${message.sender}',
          display: new SuggestionDisplay(
              headline: 'Message from ${message.sender}',
              color: 0xFFFF0080,
              annoyance: AnnoyanceType.none),
          onSelected: <Action>[
            const Action.withFocusStory(const FocusStory(storyId: ''))
          ]);
}
