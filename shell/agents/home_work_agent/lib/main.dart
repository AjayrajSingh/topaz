// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
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

const String _kLocationHomeWorkTopic = '/location/home_work';

enum _Location {
  home,
  work,
  unknown,
}

HomeWorkAgent _agent;

/// An implementation of the [Agent] interface.
class HomeWorkAgent extends AgentImpl {
  final ProposalPublisherProxy _proposalPublisher =
      new ProposalPublisherProxy();
  final ContextPublisherProxy _contextPublisher = new ContextPublisherProxy();
  final ContextProviderProxy _contextProvider = new ContextProviderProxy();
  final ContextListenerBinding _contextListenerBinding =
      new ContextListenerBinding();
  final Set<CustomActionBinding> _bindingSet = new Set<CustomActionBinding>();

  _Location _currentLocation = _Location.unknown;

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

    _contextProvider.subscribe(
      new ContextQuery()..topics = <String>[_kLocationHomeWorkTopic],
      _contextListenerBinding.wrap(
        new _ContextListenerImpl(
          proposalPublisher: _proposalPublisher,
          onTopicChanged: (String location) {
            _kHomeProposals.forEach(_proposalPublisher.remove);
            _kWorkProposals.forEach(_proposalPublisher.remove);
            _proposalPublisher.propose(_proposal);
            switch (location) {
              case 'work':
                _kWorkProposals
                    .map(_createDummyProposal)
                    .forEach(_proposalPublisher.propose);
                break;
              case 'home':
                _kHomeProposals
                    .map(_createDummyProposal)
                    .forEach(_proposalPublisher.propose);
                break;
              default:
                break;
            }
          },
        ),
      ),
    );

    _publish();
  }

  @override
  Future<Null> onStop() async {
    _contextPublisher.ctrl.close();
    _contextProvider.ctrl.close();
    _proposalPublisher.ctrl.close();
    _contextListenerBinding.close();
    _bindingSet.forEach((CustomActionBinding binding) => binding.close());
  }

  /// Publishes context indicating the user is at home.
  void publishHome() {
    _currentLocation = _Location.home;
    _publish();
  }

  /// Publishes context indicating the user is at work.
  void publishWork() {
    _currentLocation = _Location.work;
    _publish();
  }

  /// Publishes context indicating the user is neither at home nor work.
  void publishUnknown() {
    _currentLocation = _Location.unknown;
    _publish();
  }

  void _publish() => _contextPublisher.publish(
        _kLocationHomeWorkTopic,
        _locationToString(_currentLocation),
      );

  String _locationToString(_Location location) {
    switch (location) {
      case _Location.home:
        return 'home';
      case _Location.work:
        return 'work';
      default:
        return 'unknown';
    }
  }

  Proposal get _proposal {
    CustomActionBinding binding = new CustomActionBinding();
    _bindingSet.add(binding);
    final _Location nextLocation = _getNextLocation(_currentLocation);
    return new Proposal()
      ..id = 'Home/Work ${_locationToString(_currentLocation)}'
      ..display = (new SuggestionDisplay()
        ..headline = 'Set location to ${_locationToString(nextLocation)}.'
        ..subheadline = ''
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl = '')
      ..onSelected = <Action>[
        new Action()
          ..customAction = binding.wrap(
            new _CustomActionImpl(onExecute: () {
              switch (nextLocation) {
                case _Location.home:
                  publishHome();
                  break;
                case _Location.work:
                  publishWork();
                  break;
                default:
                  publishUnknown();
                  break;
              }
            }),
          )
      ];
  }

  Proposal _createDummyProposal(String title) {
    CustomActionBinding binding = new CustomActionBinding();
    _bindingSet.add(binding);
    return new Proposal()
      ..id = title
      ..display = (new SuggestionDisplay()
        ..headline = title
        ..subheadline = ''
        ..details = ''
        ..color = 0xFFFF0080
        ..iconUrls = const <String>[]
        ..imageType = SuggestionImageType.other
        ..imageUrl = '')
      ..onSelected = <Action>[
        new Action()
          ..customAction = binding.wrap(
            new _CustomActionImpl(onExecute: () => null),
          )
      ];
  }

  _Location _getNextLocation(_Location location) {
    switch (location) {
      case _Location.home:
        return _Location.work;
      case _Location.work:
        return _Location.unknown;
      default:
        return _Location.home;
    }
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

typedef void _OnExecute();

class _CustomActionImpl extends CustomAction {
  final _OnExecute onExecute;

  _CustomActionImpl({this.onExecute});

  @override
  void execute(void callback(List<Action> actions)) {
    onExecute();
    callback(<Action>[]);
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
