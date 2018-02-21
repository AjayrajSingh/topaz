// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:lib.agent.dart/agent.dart';
import 'package:lib.agent.fidl.agent_controller/agent_controller.fidl.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.fidl._service_provider/service_provider.fidl.dart';
import 'package:lib.auth.fidl/token_provider.fidl.dart';
import 'package:lib.context.fidl/context_reader.fidl.dart';
import 'package:lib.context.fidl/metadata.fidl.dart';
import 'package:lib.context.fidl/value_type.fidl.dart';
import 'package:lib.fidl.dart/bindings.dart';
import 'package:lib.logging/logging.dart';
import 'package:lib.suggestion.fidl/proposal_publisher.fidl.dart';
import 'package:lib.user.fidl/device_map.fidl.dart';
import 'package:lib.user_intelligence.fidl/intelligence_services.fidl.dart';
import 'package:meta/meta.dart';
import 'package:topaz.app.chat.services/chat_content_provider.fidl.dart';
import 'package:topaz.app.chat.services/firebase_db_client.fidl.dart';

import 'src/chat_content_provider_impl.dart';
import 'src/firebase_chat_message_transporter.dart';
import 'src/proposer.dart';

const Duration _kTimeout = const Duration(seconds: 3);
const String _kFirebaseDbAgentUrl = 'firebase_db_client';

// ignore: unused_element
ChatContentProviderAgent _agent;

/// An implementation of the [Agent] interface.
class ChatContentProviderAgent extends AgentImpl {
  final ProposalPublisherProxy _proposalPublisher =
      new ProposalPublisherProxy();
  final ContextReaderProxy _contextReader = new ContextReaderProxy();
  final ContextListenerBinding _proposerBinding = new ContextListenerBinding();
  ChatContentProviderImpl _contentProviderImpl;

  final FirebaseDbConnectorProxy _firebaseDbConnector =
      new FirebaseDbConnectorProxy();
  final AgentControllerProxy _firebaseDbAgentController =
      new AgentControllerProxy();

  /// Creates a new instance of [ChatContentProviderAgent].
  ChatContentProviderAgent({@required ApplicationContext applicationContext})
      : super(applicationContext: applicationContext);

  @override
  Future<Null> onReady(
    ApplicationContext applicationContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    log.fine('onReady start.');

    // Get the device id.
    DeviceMapProxy deviceMap = new DeviceMapProxy();
    connectToService(applicationContext.environmentServices, deviceMap.ctrl);
    Completer<DeviceMapEntry> entryCompleter = new Completer<DeviceMapEntry>();
    deviceMap.getCurrentDevice(entryCompleter.complete);
    DeviceMapEntry entry = await entryCompleter.future.timeout(_kTimeout);
    String deviceId = entry.deviceId;
    deviceMap.ctrl.close();

    IntelligenceServicesProxy intelligenceServices =
        new IntelligenceServicesProxy();
    agentContext.getIntelligenceServices(intelligenceServices.ctrl.request());
    intelligenceServices
      ..getProposalPublisher(_proposalPublisher.ctrl.request())
      ..getContextReader(_contextReader.ctrl.request())
      ..ctrl.close();

    Proposer proposer = new Proposer(proposalPublisher: _proposalPublisher);

    ContextSelector selector = new ContextSelector(
        type: ContextValueType.entity,
        meta: const ContextMetadata(
            entity: const EntityMetadata(topic: 'location/home_work')));
    ContextQuery query = new ContextQuery(
        selector: <String, ContextSelector>{'location/home_work': selector});
    _contextReader.subscribe(query, _proposerBinding.wrap(proposer));

    // Connect to the firebase db client agent and obtain the connector service.
    ServiceProviderProxy firebaseServices = new ServiceProviderProxy();
    componentContext.connectToAgent(
      _kFirebaseDbAgentUrl,
      firebaseServices.ctrl.request(),
      _firebaseDbAgentController.ctrl.request(),
    );
    connectToService(firebaseServices, _firebaseDbConnector.ctrl);
    firebaseServices.ctrl.close();

    // Initialize the content provider.
    _contentProviderImpl = new ChatContentProviderImpl(
      componentContext: componentContext,
      chatMessageTransporter: new FirebaseChatMessageTransporter(
        firebaseDbConnector: _firebaseDbConnector,
      ),
      deviceId: deviceId,
      onMessageReceived: proposer.onMessageReceived,
    );
    await _contentProviderImpl.initialize();

    // Register the ChatContentProvider service to the outgoingServices
    // service provider.
    outgoingServices.addServiceForName(
      (InterfaceRequest<ChatContentProvider> request) {
        log.fine('Received a ChatContentProvider request');
        _contentProviderImpl.addBinding(request);
      },
      ChatContentProvider.serviceName,
    );

    proposer.load();
    log.fine('onReady end.');
  }

  @override
  Future<Null> onStop() async {
    _proposalPublisher.ctrl.close();
    _contextReader.ctrl.close();
    _proposerBinding.close();
    _firebaseDbConnector.ctrl.close();
    _firebaseDbAgentController.ctrl.close();
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger(name: 'chat/agent');

  _agent = new ChatContentProviderAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
