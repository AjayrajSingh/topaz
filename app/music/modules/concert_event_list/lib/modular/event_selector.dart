// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show VoidCallback;

import 'package:fuchsia.fidl.modular/modular.dart';

class _EventData {
  final String hotWordPhrase;
  final VoidCallback onSelected;
  _EventData({this.hotWordPhrase, this.onSelected});
}

/// Proposes suggestions for selecting events with high confidence.
class EventSelector implements QueryHandler {
  final IntelligenceServicesProxy _intelligenceServicesProxy =
      new IntelligenceServicesProxy();
  final ProposalPublisherProxy _proposalPublisherProxy =
      new ProposalPublisherProxy();
  final QueryHandlerBinding _queryHandlerBinding = new QueryHandlerBinding();
  final Map<String, _EventData> _registeredEvents = <String, _EventData>{};
  final Set<CustomActionBinding> _bindings = new Set<CustomActionBinding>();
  bool _storyInFocus = false;

  /// Registers [hotWordPhrase] that when asked for will trigger [onSelected].
  /// [id] should be used to call [deregisterEvent] when this event is no longer
  /// valid.
  void registerEvent(
    String id,
    String hotWordPhrase,
    VoidCallback onSelected,
  ) {
    _registeredEvents[id] = new _EventData(
      hotWordPhrase: hotWordPhrase.toLowerCase(),
      onSelected: onSelected,
    );
  }

  /// Sets the story id this module is running within.
  set storyInFocus(bool storyInFocus) {
    _storyInFocus = storyInFocus;
  }

  /// Deregisters the event registered with [id].
  void deregisterEvent(String id) {
    _registeredEvents.remove(id);
  }

  /// Deregisters all registered events.
  void deregisterAllEvents() {
    _registeredEvents.clear();
  }

  /// Starts the proposal process.
  void start(ModuleContext moduleContext) {
    moduleContext.getIntelligenceServices(
      _intelligenceServicesProxy.ctrl.request(),
    );
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

    if (_storyInFocus) {
      String queryText = query.text?.toLowerCase();

      if (queryText != null) {
        for (_EventData eventData in _registeredEvents.values) {
          if ((queryText.contains('choose') ||
                  queryText.contains('show') ||
                  queryText.contains('select') ||
                  queryText.contains('more')) &&
              queryText.contains(eventData.hotWordPhrase)) {
            _SelectEventCustomAction selectEventCustomAction =
                new _SelectEventCustomAction(eventData);
            CustomActionBinding binding = new CustomActionBinding();
            _bindings.add(binding);
            proposals.add(new Proposal(
              id: 'Select ${eventData.hotWordPhrase}',
              confidence: 1.0,
              display: new SuggestionDisplay(
                  headline: 'Select ${eventData.hotWordPhrase}',
                  subheadline: '',
                  details: '',
                  color: 0xFFA5A700,
                  annoyance: AnnoyanceType.none),
              onSelected: <Action>[
                new Action.withCustomAction(
                    binding.wrap(selectEventCustomAction))
              ],
            ));
          }
        }
      }
    }

    callback(new QueryResponse(proposals: proposals));
  }
}

class _SelectEventCustomAction implements CustomAction {
  final _EventData eventData;

  _SelectEventCustomAction(this.eventData);

  @override
  void execute(void callback(List<Action> actions)) {
    eventData.onSelected();
  }
}
