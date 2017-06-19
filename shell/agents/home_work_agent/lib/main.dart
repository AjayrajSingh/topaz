// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.suggestion/ask_handler.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.maxwell.services.suggestion/user_input.fidl.dart';
import 'package:apps.maxwell.services.context/context_provider.fidl.dart';
import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:lib.modular/modular.dart';
import 'package:meta/meta.dart';

const List<String> _kWorkProposals = const <String>[
  'Work Suggestion 1',
  'Work Suggestion 2',
  'Work Suggestion 3',
];

const List<String> _kHomeProposals = const <String>[
  'Home Suggestion 1',
  'Home Suggestion 2',
  'Home Suggestion 3',
];

const String _kConfigFile =
    '/system/data/sysui/contextual_location_proposals.json';
const String _kAskProposalsFile = '/system/data/sysui/ask_proposals.json';

const String _kLocationHomeWorkTopic = '/location/home_work';

HomeWorkAgent _agent;

/// An implementation of the [Agent] interface.
class HomeWorkAgent extends AgentImpl {
  final ProposalPublisherProxy _proposalPublisher =
      new ProposalPublisherProxy();
  final ContextPublisherProxy _contextPublisher = new ContextPublisherProxy();
  final ContextProviderProxy _contextProvider = new ContextProviderProxy();
  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();
  final AskHandlerBinding _askHandlerBinding = new AskHandlerBinding();

  /// Constructor.
  HomeWorkAgent({
    @required ApplicationContext applicationContext,
  })
      : super(applicationContext: applicationContext);

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    IntelligenceServicesProxy intelligenceServices =
        new IntelligenceServicesProxy();
    agentContext.getIntelligenceServices(intelligenceServices.ctrl.request());
    intelligenceServices.getContextPublisher(_contextPublisher.ctrl.request());
    intelligenceServices.getProposalPublisher(
      _proposalPublisher.ctrl.request(),
    );
    intelligenceServices.getContextProvider(_contextProvider.ctrl.request());
    intelligenceServices.ctrl.close();

    final Map<String, List<Map<String, String>>> proposals =
        convert.JSON.decode(
      new File(_kConfigFile).readAsStringSync(),
    );

    _contextProvider.subscribe(
      new ContextQuery()..topics = <String>[_kLocationHomeWorkTopic],
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(
          proposalPublisher: _proposalPublisher,
          onTopicChanged: (String locationJson) {
            final Map<String, String> json = convert.JSON.decode(locationJson);
            if (json['location']?.isEmpty ?? true) {
              return;
            }

            // Remove all proposals.
            proposals.values.forEach(
              (List<Map<String, String>> proposalCategories) =>
                  proposalCategories.forEach(
                    (Map<String, String> proposal) =>
                        _proposalPublisher.remove(proposal['id']),
                  ),
            );

            // Add proposals for this location.
            if (proposals.keys.contains(json['location'])) {
              proposals[json['location']]
                  .forEach((Map<String, String> proposal) {
                _proposalPublisher.propose(_createProposal(proposal));
              });
            }
          },
        ),
      ),
    );

    final List<Map<String, String>> askProposals = convert.JSON.decode(
      new File(_kAskProposalsFile).readAsStringSync(),
    );

    _proposalPublisher.registerAskHandler(
      _askHandlerBinding.wrap(new _AskHandlerImpl(askProposals: askProposals)),
    );
  }

  @override
  Future<Null> onStop() async {
    _contextPublisher.ctrl.close();
    _contextProvider.ctrl.close();
    _proposalPublisher.ctrl.close();
    _contextListenerBinding.close();
    _askHandlerBinding.close();
  }
}

typedef void _OnTopicChanged(String topicValue);

class _ContextListenerImpl extends ContextListener {
  final ProposalPublisher proposalPublisher;
  final _OnTopicChanged onTopicChanged;

  _ContextListenerImpl({this.proposalPublisher, this.onTopicChanged});

  @override
  void onUpdate(ContextUpdate result) =>
      onTopicChanged(result.values[_kLocationHomeWorkTopic]);
}

class _AskHandlerImpl extends AskHandler {
  final List<Map<String, String>> askProposals;

  _AskHandlerImpl({this.askProposals});

  @override
  void ask(UserInput query, void callback(List<Proposal> proposals)) {
    List<Proposal> proposals = <Proposal>[];

    if (query.text?.toLowerCase()?.startsWith('demo') ?? false) {
      proposals.addAll(askProposals.map(_createProposal));
    }

    callback(proposals);
  }
}

Future<Null> main(List<dynamic> args) async {
  ApplicationContext applicationContext =
      new ApplicationContext.fromStartupInfo();
  _agent = new HomeWorkAgent(
    applicationContext: applicationContext,
  );
  _agent.advertise();
}

Proposal _createProposal(Map<String, String> proposal) => new Proposal()
  ..id = proposal['id']
  ..display = (new SuggestionDisplay()
    ..headline = proposal['headline'] ?? ''
    ..subheadline = proposal['subheadline'] ?? ''
    ..details = ''
    ..color = 0xFFFF0080
    ..iconUrls = proposal['icon_url'] != null
        ? <String>[proposal['icon_url']]
        : const <String>[]
    ..imageType = 'person' == proposal['type']
        ? SuggestionImageType.person
        : SuggestionImageType.other
    ..imageUrl = proposal['image_url'] ?? ''
    ..annoyance = AnnoyanceType.none)
  ..onSelected = <Action>[
    new Action()
      ..createStory = (new CreateStory()
        ..moduleId = proposal['module_url'] ?? ''
        ..initialData = proposal['module_data'] ?? '')
  ];
