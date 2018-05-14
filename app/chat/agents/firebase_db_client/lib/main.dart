// Copyright 2017 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:fidl/fidl.dart';
import 'package:fidl_chat_content_provider/fidl.dart';
import 'package:fidl_modular_auth/fidl.dart';
import 'package:lib.agent.dart/agent.dart';
import 'package:lib.app.dart/app.dart';
import 'package:lib.app.dart/logging.dart';
import 'package:meta/meta.dart';

import 'src/firebase_db_connector_impl.dart';

// ignore: unused_element
FirebaseDBClientAgent _agent;

/// An implementation of the [Agent] interface.
class FirebaseDBClientAgent extends AgentImpl {
  FirebaseDbConnectorImpl _connectorImpl;
  final List<FirebaseDbConnectorBinding> _connectorBindings =
      <FirebaseDbConnectorBinding>[];

  /// Creates a new instance of [FirebaseDBClientAgent].
  FirebaseDBClientAgent({@required ApplicationContext applicationContext})
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

    // Initialize the connector service.
    _connectorImpl = new FirebaseDbConnectorImpl(
      tokenProvider: tokenProvider,
    );

    // Register the FirebaseDBConnector service to the outgoingServices
    // service provider.
    outgoingServices.addServiceForName(
      (InterfaceRequest<FirebaseDbConnector> request) {
        log.fine('Received a FirebaseDbConnector request');
        _connectorBindings.add(
          new FirebaseDbConnectorBinding()..bind(_connectorImpl, request),
        );
      },
      FirebaseDbConnector.$serviceName,
    );

    log.fine('onReady end.');
  }

  @override
  Future<Null> onStop() async {
    // TODO: close all the bindings.
  }
}

/// Main entry point.
Future<Null> main(List<String> args) async {
  setupLogger(name: 'chat/firebase_db_client');

  _agent = new FirebaseDBClientAgent(
    applicationContext: new ApplicationContext.fromStartupInfo(),
  )..advertise();
}
