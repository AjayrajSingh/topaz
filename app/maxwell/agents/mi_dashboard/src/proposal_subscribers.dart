// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

import 'package:lib.app.dart/app.dart';
import 'package:lib.images.fidl/encoded_image.fidl.dart';
import 'package:lib.suggestion.fidl._debug/debug.fidl.dart';
import 'package:lib.suggestion.fidl._suggestion_provider/suggestion_display.fidl.dart';

import 'data_handler.dart';

// ignore_for_file: public_member_api_docs

Function listEqual = const ListEquality<ProposalSummary>().equals;

class ProposalSubscribersDataHandler extends AskProposalListener
    with NextProposalListener, InterruptionProposalListener, DataHandler {
  @override
  String get name => 'proposal_subscribers';

  AskProposalListenerBinding _askListenerBinding;
  NextProposalListenerBinding _nextListenerBinding;
  InterruptionProposalListenerBinding _interruptionListenerBinding;

  List<ProposalSummary> _currentNextProposals = <ProposalSummary>[];
  List<ProposalSummary> _lastAskProposals = <ProposalSummary>[];
  String _lastQuery = '';
  ProposalSummary _lastSelectedProposal;
  ProposalSummary _lastInterruptionProposal;

  SendWebSocketMessage _sendMessage;

  Map<String, dynamic> _encodeEncodedImage(EncodedImage ei) =>
      <String, int>{'size': ei.size};

  Map<String, dynamic> _encodeSuggestionDisplayImage(
      SuggestionDisplayImage sdi) {
    if (sdi == null) {
      return null;
    }
    return <String, dynamic>{
      'image': _encodeEncodedImage(sdi.image),
      'type': sdi.imageType.fidlEnumValue,
    };
  }

  Map<String, dynamic> _encodeSuggestionDisplay(SuggestionDisplay sd) =>
      <String, dynamic>{
        'headline': sd.headline,
        'subheadline': sd.subheadline,
        'details': sd.details,
        'color': sd.color,
        'annoyance': sd.annoyance.fidlEnumValue,
        'icons': (sd.icons ?? <SuggestionDisplayImage>[])
            .map(_encodeSuggestionDisplayImage)
            .toList(),
        'image': _encodeSuggestionDisplayImage(sd.image),
      };

  dynamic _encodeProposalSummary(ProposalSummary ps) {
    if (ps == null) {
      return null;
    }
    return <String, dynamic>{
      'id': ps.id,
      'publisherUrl': ps.publisherUrl,
      'display': _encodeSuggestionDisplay(ps.display),
    };
  }

  String _makeJsonMessage() {
    return json.encode(<String, dynamic>{
      'suggestions': <String, dynamic>{
        'ask_query': _lastQuery,
        'ask_proposals': _lastAskProposals.map(_encodeProposalSummary).toList(),
        'selection': _encodeProposalSummary(_lastSelectedProposal),
        'next_proposals':
            _currentNextProposals.map(_encodeProposalSummary).toList(),
        'interruption': _encodeProposalSummary(_lastInterruptionProposal),
      }
    });
  }

  @override
  void init(ApplicationContext appContext, SendWebSocketMessage sender) {
    _sendMessage = sender;

    final SuggestionDebugProxy suggestionDebug = new SuggestionDebugProxy();
    _askListenerBinding = new AskProposalListenerBinding();
    _nextListenerBinding = new NextProposalListenerBinding();
    _interruptionListenerBinding = new InterruptionProposalListenerBinding();
    connectToService(appContext.environmentServices, suggestionDebug.ctrl);
    assert(suggestionDebug.ctrl.isBound);

    // Watch for Ask, Next, and Interruption proposal changes.
    suggestionDebug
      ..watchAskProposals(_askListenerBinding.wrap(this))
      ..watchNextProposals(_nextListenerBinding.wrap(this))
      ..watchInterruptionProposals(_interruptionListenerBinding.wrap(this))
      ..ctrl.close();
  }

  @override
  bool handleRequest(String requestString, HttpRequest request) {
    return false;
  }

  @override
  void handleNewWebSocket(WebSocket socket) {
    socket.add(_makeJsonMessage());
  }

  @override
  void onAskStart(String query, List<ProposalSummary> proposals) {
    if (!listEqual(_lastAskProposals, proposals) || (_lastQuery != query)) {
      _lastAskProposals = proposals;
      _lastQuery = query;
      _sendMessage(_makeJsonMessage());
    }
  }

  @override
  void onProposalSelected(ProposalSummary selectedProposal) {
    if (_lastSelectedProposal != selectedProposal) {
      _lastSelectedProposal = selectedProposal;
      _sendMessage(_makeJsonMessage());
    }
  }

  @override
  void onNextUpdate(List<ProposalSummary> proposals) {
    if (!listEqual(_currentNextProposals, proposals)) {
      _currentNextProposals = proposals;
      _sendMessage(_makeJsonMessage());
    }
  }

  @override
  void onInterrupt(ProposalSummary interruptionProposal) {
    if (_lastInterruptionProposal != interruptionProposal) {
      _lastInterruptionProposal = interruptionProposal;
      _sendMessage(_makeJsonMessage());
    }
  }
}
