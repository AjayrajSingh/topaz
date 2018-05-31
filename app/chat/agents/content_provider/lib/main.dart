// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_chat_content_provider/fidl.dart';
import 'package:fidl_component/fidl.dart';
import 'package:fidl_fuchsia_modular/fidl.dart';
import 'package:fidl_modular_auth/fidl.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

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
  ChatContentProviderAgent({@required StartupContext startupContext})
      : super(startupContext: startupContext);

  @override
  Future<Null> onReady(
    StartupContext startupContext,
    AgentContext agentContext,
    ComponentContext componentContext,
    TokenProvider tokenProvider,
    ServiceProviderImpl outgoingServices,
  ) async {
    log.fine('onReady start.');

    // Get the device id.
    DeviceMapProxy deviceMap = new DeviceMapProxy();
    connectToService(startupContext.environmentServices, deviceMap.ctrl);
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
    ContextQuery query = new ContextQuery(selector: <ContextQueryEntry>[
      new ContextQueryEntry(key: 'location/home_work', value: selector)
    ]);
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
      ChatContentProvider.$serviceName,
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
    startupContext: new StartupContext.fromStartupInfo(),
  )..advertise();
}
