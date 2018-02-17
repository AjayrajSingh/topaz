// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';

import 'package:lib.app.dart/app.dart';
import 'package:lib.fidl.dart/bindings.dart' as fidl;
import 'package:lib.suggestion.fidl._debug/debug.fidl.dart';
import 'package:zircon/zircon.dart' as zircon;

import 'data_handler.dart';

// ignore_for_file: public_member_api_docs

Function listEqual = const ListEquality<ProposalSummary>().equals;

/// Helper for encoding some FIDL types.
Object _toEncodable(Object object) {
  if (object is fidl.Struct) {
    return object.toJson();
  }
  if (object is fidl.FidlEnum) {
    return object.toString();
  }
  if (object is zircon.Vmo) {
    return 'Vmo(handle=${object.handle} size=${object.getSize()})';
  }
  return object;
}

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

  String makeJsonMessage() {
    return JSON.encode(<String, dynamic>{
      'suggestions': <String, dynamic>{
        'ask_query': _lastQuery,
        'ask_proposals': _lastAskProposals,
        'selection': _lastSelectedProposal,
        'next_proposals': _currentNextProposals,
        'interruption': _lastInterruptionProposal,
      }
    }, toEncodable: _toEncodable);
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
    socket.add(makeJsonMessage());
  }

  @override
  void onAskStart(String query, List<ProposalSummary> proposals) {
    if (!listEqual(_lastAskProposals, proposals) || (_lastQuery != query)) {
      _lastAskProposals = proposals;
      _lastQuery = query;
      _sendMessage(makeJsonMessage());
    }
  }

  @override
  void onProposalSelected(ProposalSummary selectedProposal) {
    if (_lastSelectedProposal != selectedProposal) {
      _lastSelectedProposal = selectedProposal;
      _sendMessage(makeJsonMessage());
    }
  }

  @override
  void onNextUpdate(List<ProposalSummary> proposals) {
    if (!listEqual(_currentNextProposals, proposals)) {
      _currentNextProposals = proposals;
      _sendMessage(makeJsonMessage());
    }
  }

  @override
  void onInterrupt(ProposalSummary interruptionProposal) {
    if (_lastInterruptionProposal != interruptionProposal) {
      _lastInterruptionProposal = interruptionProposal;
      _sendMessage(makeJsonMessage());
    }
  }
}
