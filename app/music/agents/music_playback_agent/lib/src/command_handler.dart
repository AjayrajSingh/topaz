// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:fuchsia.fidl.modular/modular.dart';

/// Typedef for VoidCallback
typedef void VoidCallback();

/// Proposes high confidence suggestions for playback commands (play, pause)
class CommandHandler implements QueryHandler {
  final IntelligenceServicesProxy _intelligenceServicesProxy =
      new IntelligenceServicesProxy();
  final ProposalPublisherProxy _proposalPublisherProxy =
      new ProposalPublisherProxy();
  final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();
  final Set<CustomActionBinding> _bindings = new Set<CustomActionBinding>();

  /// Callback for when the play command is given
  final VoidCallback onPlay;

  /// Callback for when the pause command is given
  final VoidCallback onPause;

  /// Constructor
  CommandHandler({
    this.onPlay,
    this.onPause,
  });

  /// Starts the proposal process.
  void start(AgentContext agentContext) {
    agentContext
        .getIntelligenceServices(_intelligenceServicesProxy.ctrl.request());
    _intelligenceServicesProxy
      ..getProposalPublisher(
        _proposalPublisherProxy.ctrl.request(),
      )
      ..registerQueryHandler(
        _queryHandlerBinding.wrap(this),
      );
  }

  /// Cleans up any handles opened by [start].
  void stop() {
    _proposalPublisherProxy.ctrl.close();
    _queryHandlerBinding.close();
    for (CustomActionBinding binding in _bindings) {
      binding.close();
    }
    _intelligenceServicesProxy.ctrl.close();
  }

  @override
  void onQuery(UserInput query, void callback(QueryResponse response)) {
    List<Proposal> proposals = <Proposal>[];

    String queryText = query.text?.toLowerCase();
    _SelectEventCustomAction action;
    if (queryText != null) {
      if (queryText.contains('audio') || queryText.contains('music')) {
        if (queryText.contains('pause') || queryText.contains('stop')) {
          action = new _SelectEventCustomAction(onPause);
        } else if (queryText.contains('start') || queryText.contains('play')) {
          action = new _SelectEventCustomAction(onPlay);
        }
      }
      if (action != null) {
        CustomActionBinding binding = new CustomActionBinding();
        _bindings.add(binding);
        proposals.add(new Proposal(
          id: 'Music Command',
          confidence: 1.0,
          display: new SuggestionDisplay(
              headline: 'Music Command',
              subheadline: '',
              details: '',
              color: 0xFFA5A700,
              annoyance: AnnoyanceType.none),
          onSelected: <Action>[
            new Action.withCustomAction(binding.wrap(action))
          ],
        ));
      }
    }

    callback(new QueryResponse(proposals: proposals));
  }
}

class _SelectEventCustomAction implements CustomAction {
  final VoidCallback onSelected;

  _SelectEventCustomAction(this.onSelected);

  @override
  void execute(void callback(List<Action> actions)) {
    onSelected();
  }
}
