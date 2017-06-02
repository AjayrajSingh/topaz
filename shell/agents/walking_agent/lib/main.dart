// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.suggestion/proposal.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.suggestion/suggestion_display.fidl.dart';
import 'package:apps.maxwell.services.context/context_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:lib.modular/modular.dart';
import 'package:meta/meta.dart';

const String _kActivityWalkingTopic = '/activity/walking';

enum _Activity {
  walking,
  unknown,
}

WalkingAgent _agent;

/// An implementation of the [Agent] interface.
class WalkingAgent extends AgentImpl {
  final ProposalPublisherProxy _proposalPublisher =
      new ProposalPublisherProxy();
  final ContextPublisherProxy _contextPublisher = new ContextPublisherProxy();
  final Set<CustomActionBinding> _bindingSet = new Set<CustomActionBinding>();

  _Activity _currentActivity = _Activity.unknown;

  /// Constructor.
  WalkingAgent({
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
    intelligenceServices.ctrl.close();
    _publish();
    _propose();
  }

  @override
  Future<Null> onStop() async {
    _contextPublisher.ctrl.close();
    _proposalPublisher.ctrl.close();
    _bindingSet.forEach((CustomActionBinding binding) => binding.close());
  }

  /// Publishes context indicating the user is walking.
  void publishWalking() {
    _currentActivity = _Activity.walking;
    _publish();
    _propose();
  }

  /// Publishes context indicating the user is not walking.
  void publishUnknown() {
    _currentActivity = _Activity.unknown;
    _publish();
    _propose();
  }

  void _publish() => _contextPublisher.publish(
        _kActivityWalkingTopic,
        _activityToString(_currentActivity),
      );

  void _propose() => _proposalPublisher.propose(_proposal);

  String _activityToString(_Activity activity) {
    switch (activity) {
      case _Activity.walking:
        return 'walking';
      default:
        return 'unknown';
    }
  }

  Proposal get _proposal {
    CustomActionBinding binding = new CustomActionBinding();
    _bindingSet.add(binding);
    final _Activity nextActivity = _getNextActivity(_currentActivity);
    return new Proposal()
      ..id = 'Activity ${_activityToString(_currentActivity)}'
      ..display = (new SuggestionDisplay()
        ..headline = 'Set activity to ${_activityToString(nextActivity)}.'
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
              switch (nextActivity) {
                case _Activity.walking:
                  publishWalking();
                  break;
                default:
                  publishUnknown();
                  break;
              }
            }),
          )
      ];
  }

  _Activity _getNextActivity(_Activity activity) {
    switch (activity) {
      case _Activity.walking:
        return _Activity.unknown;
      default:
        return _Activity.walking;
    }
  }
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
  _agent = new WalkingAgent(applicationContext: applicationContext);
  _agent.advertise();
}
