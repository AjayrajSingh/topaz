// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:application.lib.app.dart/app.dart';
import 'package:apps.maxwell.services.context/context_reader.fidl.dart';
import 'package:apps.maxwell.services.suggestion/proposal_publisher.fidl.dart';
import 'package:apps.maxwell.services.user/intelligence_services.fidl.dart';
import 'package:lib.modular/modular.dart';
import 'package:meta/meta.dart';

import 'home_work_proposer.dart';

HomeWorkAgent _agent;

/// An implementation of the [Agent] interface.
class HomeWorkAgent extends AgentImpl {
  final ProposalPublisherProxy _proposalPublisher =
      new ProposalPublisherProxy();
  final ContextReaderProxy _contextReader = new ContextReaderProxy();
  final HomeWorkProposer _homeWorkProposer = new HomeWorkProposer();

  /// Constructor.
  HomeWorkAgent({@required ApplicationContext applicationContext})
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
    intelligenceServices.getProposalPublisher(
      _proposalPublisher.ctrl.request(),
    );
    intelligenceServices.getContextReader(_contextReader.ctrl.request());
    intelligenceServices.ctrl.close();

    _homeWorkProposer.start(_contextReader, _proposalPublisher);
  }

  @override
  Future<Null> onStop() async {
    _homeWorkProposer.stop();
    _contextReader.ctrl.close();
    _proposalPublisher.ctrl.close();
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
